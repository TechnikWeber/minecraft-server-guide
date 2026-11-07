#!/bin/bash
# Optional: meldet den Chunky-Fortschritt alle 5 % per ntfy und arbeitet die
# Welten nacheinander ab (Oberwelt -> Nether -> End). Laeuft per Cron alle
# 2 Minuten und nimmt sich am Ende selbst aus dem Cron.
# Braucht mc-cmd (RCON) und die zentrale Config (mc-common.sh).
#
# Vor dem Start STAGES anpassen: Mitte = Spawn-Koordinaten (Nether: X/8, Z/8).
# Die Oberwelt-Aufgabe selbst startet das Script beim ersten Lauf, wenn noch
# keine laeuft.
set -u
source /usr/local/bin/mc-common.sh

# Welt|Anzeigename|Mitte X|Mitte Z|Radius
STAGES=(
  "minecraft:overworld|Oberwelt|0|0|3000"
  "minecraft:the_nether|Nether|0|0|1000"
  "minecraft:the_end|End|0|0|1000"
)

STATE=/var/lib/mc-chunky-ntfy
mkdir -p "$STATE"
IDX=$(cat "$STATE/idx" 2>/dev/null || echo 0)
LAST=$(cat "$STATE/last" 2>/dev/null || echo 0)

start_stage() {
  IFS="|" read -r WORLD NAME CX CZ R <<< "${STAGES[$1]}"
  /usr/local/bin/mc-cmd chunky world "$WORLD" >/dev/null
  /usr/local/bin/mc-cmd chunky center "$CX" "$CZ" >/dev/null
  /usr/local/bin/mc-cmd chunky radius "$R" >/dev/null
  /usr/local/bin/mc-cmd chunky start >/dev/null
  echo "$1" > "$STATE/idx"; echo 0 > "$STATE/last"
  mc_notify "low" "arrow_forward" "Chunky ${NAME}: gestartet" "Radius ${R} um ${CX} / ${CZ}."
}

IFS="|" read -r WORLD NAME CX CZ R <<< "${STAGES[$IDX]}"
OUT=$(/usr/local/bin/mc-cmd chunky progress 2>/dev/null) || exit 0   # Server gerade nicht erreichbar

# Allererster Lauf ohne laufende Aufgabe: Oberwelt starten
if [ ! -f "$STATE/started" ]; then
  touch "$STATE/started"
  if ! echo "$OUT" | grep -q "Task running"; then start_stage 0; exit 0; fi
fi

if echo "$OUT" | grep -q "Task running for $WORLD"; then
  PCT=$(echo "$OUT" | grep -oP "\(\K[0-9.]+(?=%\))" | head -1)
  ETA=$(echo "$OUT" | grep -oP "ETA: \K[0-9:]+" | head -1)
  STEP=$(( ${PCT%.*} / 5 * 5 ))
  if [ "$STEP" -gt "$LAST" ] && [ "$STEP" -lt 100 ]; then
    mc_notify "low" "hourglass_flowing_sand" "Chunky ${NAME}: ${STEP} %" "Noch ca. ${ETA} (h:mm:ss)."
    echo "$STEP" > "$STATE/last"
  fi
  exit 0
fi
echo "$OUT" | grep -q "Task running\|paused" && exit 0   # andere Welt laeuft / pausiert

# Aktuelle Welt fertig -> melden und naechste starten
mc_notify "default" "white_check_mark" "Chunky ${NAME}: fertig" "Die ${NAME} ist vorgeneriert."
IDX=$((IDX+1))
if [ "$IDX" -ge "${#STAGES[@]}" ]; then
  mc_notify "default" "tada" "Chunky: alles fertig" "Alle Welten sind vorgeneriert. Chunky kann jetzt entfernt werden."
  crontab -l | grep -v mc-chunky-ntfy.sh | crontab -
  rm -rf "$STATE"
  exit 0
fi
start_stage "$IDX"

#!/bin/bash
# Watchdog fuer den Bedrock-Server: prueft alle 5 Minuten (per Cron), ob der
# Dienst laeuft. Kein geplanter Nacht-Neustart - greift nur ein, wenn der
# Server wirklich down ist. Meldet nur bei Zustandswechsel (kein Spam).
set -u
source /usr/local/bin/mc-common.sh

STATE_DIR="/var/lib/minecraft-bedrock"
STATE_FILE="$STATE_DIR/monitor.state"
RESTART_MARK="$STATE_DIR/last_restart_notice"
mkdir -p "$STATE_DIR"

if in_maintenance; then exit 0; fi

PREV=$(cat "$STATE_FILE" 2>/dev/null || echo "up")

if server_is_up; then
  if [ "$PREV" = "down" ]; then
    mc_notify "default" "white_check_mark" "Bedrock: Server wieder online" "Der Server laeuft wieder."
  fi
  echo "up" > "$STATE_FILE"
  exit 0
fi

# Dienst gerade erst gestartet, Port noch nicht offen -> faehrt noch hoch
if service_starting; then exit 0; fi

# Server ist nicht aktiv -> Reparaturversuch
systemctl reset-failed "$MC_SERVICE" 2>/dev/null
systemctl start "$MC_SERVICE" 2>/dev/null
sleep 15

if server_is_up; then
  if [ -z "$(find "$RESTART_MARK" -mmin -30 2>/dev/null)" ]; then
    mc_notify "high" "warning" "Bedrock: Server war down - neu gestartet" \
      "Der Server war nicht aktiv und wurde automatisch neu gestartet. Er laeuft jetzt wieder."
    touch "$RESTART_MARK"
  fi
  echo "up" > "$STATE_FILE"
else
  if [ "$PREV" != "down" ]; then
    mc_notify "urgent" "rotating_light" "Bedrock: Server DOWN" \
      "Der Server ist nicht aktiv und der automatische Neustart ist fehlgeschlagen. Bitte pruefen: journalctl -u $MC_SERVICE -n 50"
  fi
  echo "down" > "$STATE_FILE"
fi

#!/bin/bash
# Gemeinsame Funktionen fuer alle mc-*.sh Scripts (Bedrock und Crossplay).
# Wird von den anderen Scripts per `source /usr/local/bin/mc-common.sh` eingebunden.
# Erwartet, dass vorher eine Konfigurationsdatei geladen wurde (siehe unten).
set -u

CONF="${MC_GUIDE_CONF:-/etc/minecraft-guide.conf}"
if [ ! -f "$CONF" ]; then
  echo "Konfigurationsdatei fehlt: $CONF (siehe config/*.conf.example im Repo)" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$CONF"

mc_log() {
  echo "$(date '+%F %T') [$(basename "${0:-mc}")] $*"
}

# mc_notify <priority> <tags> <titel> <text>
# priority: min | low | default | high | urgent | max
# tags: kommagetrennte ntfy-Emoji-Codes, z.B. white_check_mark,warning
mc_notify() {
  local prio="$1" tags="$2" title="$3" body="$4"
  curl -fsS --max-time 15 \
    -H "Title: $title" -H "Priority: $prio" -H "Tags: $tags" \
    -d "$body" "${NTFY_URL}/${NTFY_TOPIC}" >/dev/null 2>&1
}

# Laeuft der Dienst wirklich (Service aktiv UND Port erreichbar, falls MC_PORT gesetzt)?
server_is_up() {
  systemctl is-active --quiet "$MC_SERVICE" || return 1
  [ -n "${MC_PORT:-}" ] || return 0
  if [ "${MC_PORT_PROTO:-tcp}" = "udp" ]; then
    ss -uln 2>/dev/null | grep -q ":${MC_PORT} "
  else
    ss -tln 2>/dev/null | grep -q ":${MC_PORT} "
  fi
}

# true, wenn der Dienst aktiv ist, aber erst vor weniger als MC_START_TIMEOUT
# Sekunden gestartet wurde - dann faehrt er vermutlich noch hoch (z.B. nach
# einem Reboot oder direkt nach dem Backup) und soll nicht neu gestartet werden.
# Nutzt die Uhrzeit statt der Uptime, weil die in einer LXC nicht zum Host passt.
service_starting() {
  systemctl is-active --quiet "$MC_SERVICE" || return 1
  local since age
  since=$(systemctl show --timestamp=unix -p ActiveEnterTimestamp --value "$MC_SERVICE" 2>/dev/null)
  since=${since#@}
  case "$since" in ''|*[!0-9]*) return 1 ;; esac
  age=$(( $(date +%s) - since ))
  [ "$age" -ge 0 ] && [ "$age" -lt "${MC_START_TIMEOUT:-120}" ]
}

# Wartungs-Flag setzen/loesen. Verhindert, dass der Watchdog waehrend
# Backup/Update Fehlalarm schlaegt.
maintenance_on() { touch "$MC_LOCKFILE"; }
maintenance_off() { rm -f "$MC_LOCKFILE"; }

# true (exit 0), wenn gerade Wartung laeuft (Flag existiert und ist frisch).
in_maintenance() {
  [ -e "$MC_LOCKFILE" ] || return 1
  if [ -n "$(find "$MC_LOCKFILE" -mmin -"${MC_LOCK_MAX_AGE_MIN:-60}" 2>/dev/null)" ]; then
    return 0
  fi
  rm -f "$MC_LOCKFILE"   # verwaistes Flag aufraeumen
  return 1
}

# Wartet, bis ein bestimmtes Muster im Journal seit einem Zeitstempel auftaucht,
# oder auf Timeout. $1=Muster (grep -E) $2=Zeitstempel(seit) $3=Timeout in Sekunden
wait_for_log_pattern() {
  local pattern="$1" since="$2" timeout="${3:-120}" waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if journalctl -u "$MC_SERVICE" --since "$since" 2>/dev/null | grep -qE "$pattern"; then
      return 0
    fi
    systemctl is-failed --quiet "$MC_SERVICE" && return 1
    sleep 5
    waited=$((waited + 5))
  done
  return 1
}

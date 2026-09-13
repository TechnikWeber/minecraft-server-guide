#!/bin/bash
# Taegliches Backup des Bedrock-Servers. Sichert Welt(en) + Konfiguration +
# OP-Rechte + Allowlist - daraus laesst sich ein Server komplett wiederherstellen
# oder auf einen anderen LXC umziehen (siehe docs/a-bedrock, Schritt 7).
set -u
source /usr/local/bin/mc-common.sh

DATE=$(date +%Y-%m-%d_%H-%M)
BACKUP_FILE="$BACKUP_DIR/bedrock-backup-$DATE.tar.gz"
mkdir -p "$BACKUP_DIR"

# Wartungs-Flag nur setzen, wenn nicht schon eines existiert (z.B. vom Update-Script).
OWN_FLAG=false
if ! in_maintenance; then maintenance_on; OWN_FLAG=true; fi
cleanup() { [ "$OWN_FLAG" = true ] && maintenance_off; }
trap cleanup EXIT

# Nur tatsaechlich vorhandene Teile sichern
ITEMS=()
for f in worlds server.properties permissions.json allowlist.json; do
  [ -e "$MC_DIR/$f" ] && ITEMS+=("$f")
done

WAS_ACTIVE=false
if systemctl is-active --quiet "$MC_SERVICE"; then
  WAS_ACTIVE=true
  systemctl stop "$MC_SERVICE"
fi

tar -czf "$BACKUP_FILE" -C "$MC_DIR" "${ITEMS[@]}"
STATUS=$?

[ "$WAS_ACTIVE" = true ] && systemctl start "$MC_SERVICE"

find "$BACKUP_DIR" -name "bedrock-backup-*.tar.gz" -mtime +"$BACKUP_KEEP_DAYS" -delete

if [ $STATUS -eq 0 ]; then
  mc_log "Backup erstellt: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
else
  mc_log "Backup FEHLGESCHLAGEN"
  mc_notify "high" "warning" "Bedrock: Backup fehlgeschlagen" \
    "Das Backup ($DATE) ist fehlgeschlagen. Bitte pruefen: /var/log/mc-backup.log"
fi
exit $STATUS

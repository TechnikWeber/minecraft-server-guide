#!/bin/bash
# Backup fuer den Crossplay-Server: Welt + server.properties + ops/whitelist
# + Paper-Configs + alle relevanten Plugin-Configs/-Datenbanken (LuckPerms,
# GriefPrevention, CoreProtect, Essentials, Geyser/Floodgate-Config).
# Ab Paper 26.1 liegen Nether und End im Weltordner (world/dimensions/...);
# die alten Ordner world_nether/world_the_end werden nur mitgesichert, falls
# es sie noch gibt. MC_SKIP_SERVICE=1 laesst den Aufrufer (Update-Script) die
# Dienststeuerung selbst uebernehmen.
set -u
source /usr/local/bin/mc-common.sh

mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y-%m-%d_%H-%M)
BACKUP_FILE="$BACKUP_DIR/paper-backup-$DATE.tar.gz"

# Aktiven Weltnamen aus server.properties lesen (Standard: world)
LEVEL=$(grep -E '^level-name=' "$MC_DIR/server.properties" 2>/dev/null | cut -d= -f2- | tr -d '\r')
LEVEL=${LEVEL:-world}

MANAGE=1; [ "${MC_SKIP_SERVICE:-0}" = "1" ] && MANAGE=0
WAS_ACTIVE=false
if [ "$MANAGE" = "1" ]; then
  OWN_FLAG=false
  if ! in_maintenance; then maintenance_on; OWN_FLAG=true; fi
  cleanup() { [ "$OWN_FLAG" = true ] && maintenance_off; }
  trap cleanup EXIT
  # Nur stoppen (und danach wieder starten), wenn der Server auch lief -
  # ein absichtlich gestoppter Server bleibt aus.
  if systemctl is-active --quiet "$MC_SERVICE"; then
    WAS_ACTIVE=true
    systemctl stop "$MC_SERVICE"
  fi
fi

ITEMS=()
for f in "$LEVEL" "${LEVEL}_nether" "${LEVEL}_the_end" \
         server.properties whitelist.json ops.json bukkit.yml spigot.yml config \
         plugins/Geyser-Spigot/config.yml plugins/floodgate/config.yml \
         plugins/LuckPerms plugins/GriefPrevention plugins/CoreProtect \
         plugins/Essentials plugins/Chunky; do
  [ -e "$MC_DIR/$f" ] && ITEMS+=("$f")
done

tar -czf "$BACKUP_FILE" -C "$MC_DIR" "${ITEMS[@]}" 2>/dev/null
RC=$?

[ "$WAS_ACTIVE" = true ] && systemctl start "$MC_SERVICE"

find "$BACKUP_DIR" -name "paper-backup-*.tar.gz" -mtime +"$BACKUP_KEEP_DAYS" -delete

if [ "$RC" -ne 0 ] || [ ! -s "$BACKUP_FILE" ]; then
  mc_notify "high" "warning" "Crossplay: Backup-Problem" \
    "Das Backup wurde evtl. nicht sauber erstellt (rc=$RC). Datei: $BACKUP_FILE Pruefen: ls -lh $BACKUP_DIR"
fi
mc_log "Backup: $BACKUP_FILE (rc=$RC)"
exit "$RC"

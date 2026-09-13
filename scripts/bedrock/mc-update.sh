#!/bin/bash
# Auto-Update des Bedrock-Servers ueber die Mojang-API, mit vollem Rollback-Snapshot.
# Ablauf: neueste Version ermitteln -> Download+Test (Server laeuft weiter)
# -> Backup -> Server stoppen + Rollback-Snapshot -> Entpacken
# -> Start & Health-Check -> bei Fehlschlag automatischer Rollback.
set -u
source /usr/local/bin/mc-common.sh

VERSION_FILE="$MC_DIR/.installed_version"
ROLLBACK_DIR="${MC_DIR}.rollback"
BACKUP_SCRIPT="/usr/local/bin/mc-bedrock-backup.sh"

maintenance_on
cleanup() { maintenance_off; }
trap cleanup EXIT

# 1) Neueste Version ueber die Mojang-API ermitteln
mc_log "Frage neueste Bedrock-Version ab..."
LINKS_JSON=$(curl -fsS --max-time 30 -A "$MOJANG_UA" "$MOJANG_API_URL" 2>/dev/null)
DOWNLOAD_URL=$(printf '%s' "$LINKS_JSON" \
  | jq -r '.result.links[] | select(.downloadType=="serverBedrockLinux") | .downloadUrl' 2>/dev/null)

if [ -z "${DOWNLOAD_URL:-}" ] || [ "$DOWNLOAD_URL" = "null" ]; then
  mc_log "Download-URL konnte nicht ermittelt werden."
  mc_notify "high" "warning" "Bedrock: Update-Check fehlgeschlagen" \
    "Die neueste Version konnte nicht abgefragt werden (API/Netzwerk). Server laeuft unveraendert weiter."
  exit 1
fi

LATEST_VERSION=$(printf '%s' "$DOWNLOAD_URL" | sed -E 's#.*/bedrock-server-([0-9.]+)\.zip#\1#')
INSTALLED_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unbekannt")
mc_log "Installiert: $INSTALLED_VERSION / Verfuegbar: $LATEST_VERSION"

if [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then
  mc_log "Bereits aktuell - kein Update noetig."
  exit 0
fi
if [ "$INSTALLED_VERSION" != "unbekannt" ]; then
  HIGHEST=$(printf '%s\n%s\n' "$INSTALLED_VERSION" "$LATEST_VERSION" | sort -V | tail -1)
  if [ "$HIGHEST" = "$INSTALLED_VERSION" ]; then
    mc_log "Installierte Version ist nicht aelter - kein Update."
    exit 0
  fi
fi

mc_log "Update von $INSTALLED_VERSION auf $LATEST_VERSION."

# 2) Download + Integritaet pruefen - der Server laeuft dabei weiter
TMP_ZIP="/home/${MC_USER}/bedrock-server-new.zip"
mc_log "Lade neue Version herunter..."
if ! curl -fsSL --max-time 300 -A "$MOJANG_UA" -o "$TMP_ZIP" "$DOWNLOAD_URL" \
   || ! unzip -tq "$TMP_ZIP" >/dev/null 2>&1; then
  mc_log "Download/ZIP defekt."
  rm -f "$TMP_ZIP"
  mc_notify "high" "warning" "Bedrock: Update-Download fehlgeschlagen" \
    "Download von $LATEST_VERSION fehlgeschlagen. Server laeuft unveraendert mit $INSTALLED_VERSION weiter."
  exit 1
fi

# 3) Backup, dann Server stoppen und Rollback-Snapshot vom GESTOPPTEN Stand
#    (eine Kopie der laufenden Welt koennte inkonsistent sein)
if [ -x "$BACKUP_SCRIPT" ] && ! "$BACKUP_SCRIPT"; then
  rm -f "$TMP_ZIP"
  mc_notify "high" "warning" "Bedrock: Update abgebrochen" \
    "Backup vor dem Update fehlgeschlagen - Update wurde NICHT durchgefuehrt."
  exit 1
fi
systemctl stop "$MC_SERVICE"
mc_log "Erstelle Rollback-Snapshot..."
rm -rf "$ROLLBACK_DIR"
if ! cp -a "$MC_DIR" "$ROLLBACK_DIR"; then
  rm -rf "$ROLLBACK_DIR" "$TMP_ZIP"
  systemctl start "$MC_SERVICE"
  mc_notify "high" "warning" "Bedrock: Update abgebrochen" \
    "Rollback-Snapshot konnte nicht angelegt werden (Speicherplatz?). Update wurde NICHT durchgefuehrt, Server laeuft weiter."
  exit 1
fi

rollback() {
  mc_log "Rollback wird durchgefuehrt..."
  systemctl stop "$MC_SERVICE" 2>/dev/null
  rm -rf "$MC_DIR"
  mv "$ROLLBACK_DIR" "$MC_DIR"
  systemctl start "$MC_SERVICE"
  sleep 10
}

# 4) Konfig sichern, entpacken, Konfig zurueckspielen (ueberschreibt mitgelieferte Defaults)
for f in server.properties permissions.json allowlist.json; do
  [ -e "$MC_DIR/$f" ] && cp -a "$MC_DIR/$f" "/tmp/mc-$f.keep"
done
cd "$MC_DIR" || { rollback; exit 1; }
unzip -o "$TMP_ZIP" >/dev/null
rm -f "$TMP_ZIP"
chmod +x bedrock_server
for f in server.properties permissions.json allowlist.json; do
  [ -e "/tmp/mc-$f.keep" ] && cp -a "/tmp/mc-$f.keep" "$MC_DIR/$f" && rm -f "/tmp/mc-$f.keep"
done
chown -R "$MC_USER":"$MC_USER" "$MC_DIR"

# 5) Starten & verifizieren
START_TS=$(date '+%Y-%m-%d %H:%M:%S')
systemctl start "$MC_SERVICE"
mc_log "Warte auf '$MC_READY_PATTERN' (max ${MC_START_TIMEOUT}s)..."

if wait_for_log_pattern "$MC_READY_PATTERN" "$START_TS" "$MC_START_TIMEOUT" && server_is_up; then
  echo "$LATEST_VERSION" > "$VERSION_FILE"
  chown "$MC_USER":"$MC_USER" "$VERSION_FILE"
  rm -rf "$ROLLBACK_DIR"
  mc_log "Update erfolgreich."
  mc_notify "default" "white_check_mark,package" "Bedrock: Update erfolgreich" \
    "Bedrock wurde von $INSTALLED_VERSION auf $LATEST_VERSION aktualisiert und laeuft."
  exit 0
fi

mc_log "Neue Version startet nicht - Rollback."
rollback
if server_is_up; then
  mc_notify "urgent" "rotating_light" "Bedrock: Update fehlgeschlagen (Rollback)" \
    "Version $LATEST_VERSION startete nicht. Alte Version $INSTALLED_VERSION wurde wiederhergestellt und laeuft wieder."
  exit 1
else
  mc_notify "max" "rotating_light,sos" "Bedrock: KRITISCH - manueller Eingriff noetig" \
    "Update UND Rollback schlugen fehl. Sofort pruefen: journalctl -u $MC_SERVICE -n 80"
  exit 2
fi

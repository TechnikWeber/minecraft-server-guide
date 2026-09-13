#!/bin/bash
# Auto-Update fuer den Crossplay-Server. Aktualisiert automatisch NUR:
#   - Paper, aber nur Builds INNERHALB der in der Config gepinnten MC-Version
#   - Geyser + Floodgate (muessen mit Bedrock-Client-Updates Schritt halten)
# Alles andere (Paper-Major-Sprung, ViaVersion, LuckPerms/EssentialsX/
# GriefPrevention/CoreProtect/Chunky) bleibt bewusst manuell - siehe
# docs/06-wartung. Grund: Geyser ist immer der limitierende Faktor.
#
# Ablauf: Hash-Vergleich (kein unnoetiger Neustart) -> Backup -> Update ->
# Health-Check -> bei Fehlschlag automatischer Rollback pro Komponente.
# Es bleibt immer nur der Rollback-Ordner des letzten Updates liegen.
set -u
source /usr/local/bin/mc-common.sh

STAGING="$(mktemp -d /tmp/mc-update.XXXXXX)"
ROLLBACK="$MC_DIR/rollback-$(date +%Y-%m-%d_%H-%M)"
cleanup() { rm -rf "$STAGING"; maintenance_off; }
trap cleanup EXIT

valid_jar() {  # echte JAR-Datei, nicht nur eine Fehlerseite?
  [ -s "$1" ] || return 1
  [ "$(stat -c%s "$1")" -gt 500000 ] || return 1
  unzip -tqq "$1" >/dev/null 2>&1
}
changed() {    # $1 neu  $2 installiert -> 0 wenn unterschiedlich
  [ -f "$2" ] || return 0
  [ "$(sha256sum "$1" | cut -d' ' -f1)" != "$(sha256sum "$2" | cut -d' ' -f1)" ]
}

declare -A NEW DEST
NOTES=""

# --- Paper (nur Builds innerhalb der gepinnten MC-Version) ---
BUILDS=$(curl -s -A "$PAPER_UA" \
  "https://fill.papermc.io/v3/projects/${PAPER_PROJECT}/versions/${PAPER_MC_VERSION}/builds")
PAPER_URL=$(echo "$BUILDS" | jq -r 'first(.[] | select(.channel=="STABLE") | .downloads."server:default".url) // "null"' 2>/dev/null)
PAPER_BUILD=$(echo "$BUILDS" | jq -r 'first(.[] | select(.channel=="STABLE") | .id) // "?"' 2>/dev/null)
if [ "${PAPER_URL:-null}" != "null" ] && [ -n "${PAPER_URL:-}" ]; then
  curl -s -A "$PAPER_UA" -o "$STAGING/paper.jar" "$PAPER_URL"
  if valid_jar "$STAGING/paper.jar" && changed "$STAGING/paper.jar" "$MC_DIR/paper.jar"; then
    NEW[paper]="$STAGING/paper.jar"; DEST[paper]="$MC_DIR/paper.jar"
    NOTES="${NOTES}- Paper ${PAPER_MC_VERSION}-${PAPER_BUILD}
"
  fi
else
  mc_notify "default" "warning" "Crossplay: Paper-Check fehlgeschlagen" \
    "Konnte die Paper-Build-Liste nicht lesen (API/Netz?). Andere Updates laufen normal weiter."
fi

# --- Geyser ---
curl -sL -o "$STAGING/Geyser-Spigot.jar" "$GEYSER_URL"
if valid_jar "$STAGING/Geyser-Spigot.jar" && changed "$STAGING/Geyser-Spigot.jar" "$PLUGINS_DIR/Geyser-Spigot.jar"; then
  NEW[geyser]="$STAGING/Geyser-Spigot.jar"; DEST[geyser]="$PLUGINS_DIR/Geyser-Spigot.jar"
  NOTES="${NOTES}- Geyser (neuester Build)
"
fi

# --- Floodgate ---
curl -sL -o "$STAGING/floodgate-spigot.jar" "$FLOODGATE_URL"
if valid_jar "$STAGING/floodgate-spigot.jar" && changed "$STAGING/floodgate-spigot.jar" "$PLUGINS_DIR/floodgate-spigot.jar"; then
  NEW[floodgate]="$STAGING/floodgate-spigot.jar"; DEST[floodgate]="$PLUGINS_DIR/floodgate-spigot.jar"
  NOTES="${NOTES}- Floodgate (neuester Build)
"
fi

# --- Nichts Neues? Server in Ruhe lassen. ---
if [ -z "${NEW[*]+x}" ]; then
  mc_log "Keine Updates."
  exit 0
fi

maintenance_on
mc_log "Updates gefunden:"; echo "$NOTES"

systemctl stop "$MC_SERVICE"
# Welt-Backup im gestoppten Zustand. Schlaegt es fehl, wird NICHT aktualisiert.
if ! MC_SKIP_SERVICE=1 /usr/local/bin/mc-crossplay-backup.sh >/dev/null 2>&1; then
  systemctl start "$MC_SERVICE"
  mc_log "Backup fehlgeschlagen -> Update abgebrochen."
  mc_notify "high" "warning" "Crossplay: Update abgebrochen" \
    "Backup vor dem Update fehlgeschlagen - Update wurde NICHT durchgefuehrt. Server laeuft unveraendert weiter.
Pruefen: ls -lh $BACKUP_DIR"
  exit 1
fi

mkdir -p "$ROLLBACK"
for k in "${!NEW[@]}"; do
  [ -f "${DEST[$k]}" ] && cp -p "${DEST[$k]}" "$ROLLBACK/$(basename "${DEST[$k]}")"
done

for k in "${!NEW[@]}"; do cp -f "${NEW[$k]}" "${DEST[$k]}"; done
chown -R "$MC_USER":"$MC_USER" "$MC_DIR"

START_TS=$(date '+%Y-%m-%d %H:%M:%S')
systemctl start "$MC_SERVICE"

if wait_for_log_pattern "$MC_READY_PATTERN" "$START_TS" "$MC_START_TIMEOUT" && server_is_up; then
  # Aeltere Rollback-Ordner aufraeumen, nur der von diesem Lauf bleibt
  find "$MC_DIR" -maxdepth 1 -type d -name 'rollback-*' ! -path "$ROLLBACK" -exec rm -rf {} +
  mc_notify "default" "white_check_mark,arrow_up" "Crossplay: Update erfolgreich" \
    "Aktualisiert und sauber gestartet:
${NOTES}
Sicherung des alten Stands: $ROLLBACK
(wird beim naechsten erfolgreichen Update automatisch geloescht)"
  mc_log "Update OK."
  exit 0
fi

# --- Fehlschlag -> automatischer Rollback pro Komponente ---
mc_log "Health-Check fehlgeschlagen -> Rollback."
systemctl stop "$MC_SERVICE"
for f in "$ROLLBACK"/*; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  if [ "$base" = "paper.jar" ]; then cp -f "$f" "$MC_DIR/paper.jar"
  else cp -f "$f" "$PLUGINS_DIR/$base"; fi
done
chown -R "$MC_USER":"$MC_USER" "$MC_DIR"

START_TS=$(date '+%Y-%m-%d %H:%M:%S')
systemctl start "$MC_SERVICE"

if wait_for_log_pattern "$MC_READY_PATTERN" "$START_TS" "$MC_START_TIMEOUT" && server_is_up; then
  mc_notify "high" "x,leftwards_arrow_with_hook" "Crossplay: Update fehlgeschlagen (Rollback)" \
    "Ein Update startete nicht sauber. Automatisch zurueckgerollt - der Server LAEUFT wieder.
Versucht wurde:
${NOTES}
Logs: journalctl -u $MC_SERVICE -n 100
Erneut versuchen: /usr/local/bin/mc-crossplay-update.sh
Alte Jars liegen in: $ROLLBACK"
  mc_log "Rollback OK."
  exit 1
fi

mc_notify "urgent" "rotating_light" "Crossplay: KRITISCH - Server unten" \
  "Update fehlgeschlagen UND der Rollback startet nicht. Bitte sofort eingreifen:
1) journalctl -u $MC_SERVICE -n 120
2) pkill -f paper.jar ; systemctl start $MC_SERVICE
3) Hilft nicht: Backup zurueckspielen aus $BACKUP_DIR
4) Notstart von Hand: systemctl stop $MC_SERVICE; su - $MC_USER -c 'cd $MC_DIR && java -Xms2G -Xmx4G -jar paper.jar --nogui'"
mc_log "KRITISCH: Rollback fehlgeschlagen."
exit 2

#!/bin/bash
# OS-Sicherheitsupdates ueber unattended-upgrade, fuer BEIDE Wege (Bedrock
# und Crossplay) und BEIDE Distros identisch. Meldet nur, wenn wirklich
# etwas installiert wurde, ein Fehler auftrat, oder ein Neustart empfohlen ist.
#
# Einmalige Einrichtung (beide Distros):
#   apt install -y unattended-upgrades
#   systemctl disable --now apt-daily-upgrade.timer   # wir steuern das Anwenden per Cron
# Sicherheitsupdates sind auf beiden Distros ab Werk in
# /etc/apt/apt.conf.d/50unattended-upgrades freigegeben. Pruefen:
#   unattended-upgrade --dry-run -d 2>&1 | grep -i 'allowed origins'
# Die Ausgabe muss "-security" (Ubuntu) bzw. "Debian-Security" enthalten.
set -u
source /usr/local/bin/mc-common.sh

command -v unattended-upgrade >/dev/null 2>&1 || { mc_log "unattended-upgrade fehlt"; exit 0; }

apt-get update -qq
OUT="$(unattended-upgrade -v 2>&1)"; RC=$?
mc_log "$OUT"

UPG="$(echo "$OUT" | grep -iE 'Packages that will be upgraded:' | sed 's/.*upgraded: //I' | tr -s ' ')"

REBOOT_NOTE=""
[ -f /var/run/reboot-required ] && REBOOT_NOTE="

Hinweis: Ein Neustart wird empfohlen (Kernel/Lib aktualisiert). Wenn es passt: reboot"

if [ "$RC" -ne 0 ]; then
  mc_notify "high" "warning" "Host: OS-Update Problem" \
    "Sicherheitsupdates liefen nicht sauber durch (rc=$RC). Pruefen: cat /var/log/mc-os-update.log ; apt-get -f install"
elif [ -n "$UPG" ]; then
  mc_notify "low" "white_check_mark,package" "Host: Sicherheitsupdates installiert" \
    "Automatisch aktualisiert: $UPG$REBOOT_NOTE"
elif [ -n "$REBOOT_NOTE" ]; then
  mc_notify "default" "warning" "Host: Neustart empfohlen" "$REBOOT_NOTE"
fi
# sonst: nichts Neues -> keine Nachricht

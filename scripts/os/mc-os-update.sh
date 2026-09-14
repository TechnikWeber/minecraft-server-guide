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

# Neustart noetig? Ubuntu legt dafuer /var/run/reboot-required an, Debian nicht.
# Deshalb zusaetzlich pruefen, ob ein neuerer Kernel installiert ist als der
# laufende (VServer). In einer LXC liegt kein Kernel unter /boot - der kommt
# dort vom Host, die Pruefung greift dann nicht.
REBOOT_KEY=""
[ -f /var/run/reboot-required ] && REBOOT_KEY="lib-$(stat -c %Y /var/run/reboot-required)"
NEWEST_KERNEL="$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed 's#^/boot/vmlinuz-##' | sort -V | tail -1)"
if [ -n "$NEWEST_KERNEL" ] && [ "$NEWEST_KERNEL" != "$(uname -r)" ]; then
  REBOOT_KEY="${REBOOT_KEY:+$REBOOT_KEY }kernel-$NEWEST_KERNEL"
fi

REBOOT_NOTE=""
[ -n "$REBOOT_KEY" ] && REBOOT_NOTE="

Hinweis: Ein Neustart wird empfohlen (Kernel/Lib aktualisiert). Wenn es passt: reboot"

# Die eigenstaendige Neustart-Meldung nur einmal pro Anlass, nicht jede Nacht.
# Die Datei existiert, solange ein gemeldeter Neustart ansteht - ein optionaler
# Auto-Reboot per Cron (siehe Anleitungen, "Automatischer Neustart") prueft sie.
REBOOT_MARK="/var/lib/minecraft-guide/reboot-pending"
mkdir -p "$(dirname "$REBOOT_MARK")"
[ -z "$REBOOT_KEY" ] && rm -f "$REBOOT_MARK"

if [ "$RC" -ne 0 ]; then
  mc_notify "high" "warning" "Host: OS-Update Problem" \
    "Sicherheitsupdates liefen nicht sauber durch (rc=$RC). Pruefen: cat /var/log/mc-os-update.log ; apt-get -f install"
elif [ -n "$UPG" ]; then
  mc_notify "low" "white_check_mark,package" "Host: Sicherheitsupdates installiert" \
    "Automatisch aktualisiert: $UPG$REBOOT_NOTE"
  [ -n "$REBOOT_KEY" ] && echo "$REBOOT_KEY" > "$REBOOT_MARK"
elif [ -n "$REBOOT_KEY" ] && [ "$REBOOT_KEY" != "$(cat "$REBOOT_MARK" 2>/dev/null)" ]; then
  mc_notify "default" "warning" "Host: Neustart empfohlen" "$REBOOT_NOTE"
  echo "$REBOOT_KEY" > "$REBOOT_MARK"
fi
# sonst: nichts Neues -> keine Nachricht

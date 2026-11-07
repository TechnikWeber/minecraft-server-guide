#!/bin/bash
# Optional: Notfall-Weboberflaeche (Cockpit) fuer den Crossplay-Server.
#  - Cockpit (schlank: Uebersicht, Dienste, Logs) auf Port 9090
#  - gemeinsamer Benutzer "mcadmin", darf NUR minecraft-paper starten/stoppen/
#    neu starten und Logs lesen - keine Root-Rechte, kein SSH
#  - eigene Cockpit-Seite "Minecraft" mit Buttons, Status und Fehlern
#  - fail2ban: 5 falsche Passwoerter -> 1 h Sperre, nur fuer Port 9090
#  - ufw: Port 9090 freigeben (falls ufw aktiv ist)
# Mehrfach ausfuehrbar. Als root aus dem Repo-Ordner starten:
#   bash /opt/minecraft-server-guide/scripts/cockpit/setup-cockpit.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Bitte als root ausfuehren."; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

echo "==> Pakete"
apt-get update -qq
apt-get install -y -qq --no-install-recommends cockpit-ws cockpit-system cockpit-bridge polkitd >/dev/null
apt-get install -y -qq fail2ban python3-systemd >/dev/null
systemctl enable --now cockpit.socket >/dev/null

echo "==> Benutzer mcadmin"
NEWPW=""
if ! id mcadmin >/dev/null 2>&1; then
  useradd -m -s /bin/bash -c "Minecraft-Admin (Cockpit)" mcadmin
  NEWPW=$(python3 -c "import secrets,string;a=string.ascii_letters+string.digits;print('-'.join(''.join(secrets.choice(a) for _ in range(5)) for _ in range(4)))")
  echo "mcadmin:$NEWPW" | chpasswd
  (umask 077; echo "$NEWPW" > /root/cockpit-mcadmin-passwort.txt)
fi
usermod -aG systemd-journal mcadmin
echo "DenyUsers mcadmin" > /etc/ssh/sshd_config.d/10-deny-mcadmin.conf
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true   # bei Socket-Aktivierung (Debian 13) unnoetig

echo "==> Rechte-Regel (polkit)"
install -m 644 "$HERE/50-mcadmin-minecraft.rules" /etc/polkit-1/rules.d/50-mcadmin-minecraft.rules
systemctl restart polkit

echo "==> Cockpit-Seite Minecraft"
mkdir -p /usr/share/cockpit/minecraft
install -m 644 "$HERE"/minecraft/* /usr/share/cockpit/minecraft/

echo "==> fail2ban"
install -m 644 "$HERE/fail2ban-cockpit-filter.conf" /etc/fail2ban/filter.d/cockpit.conf
install -m 644 "$HERE/fail2ban-cockpit-jail.local" /etc/fail2ban/jail.d/cockpit.local
systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban

if ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "==> ufw: Port 9090"
  ufw allow 9090/tcp comment "Cockpit (Schutz: fail2ban)" >/dev/null
fi

echo "==> Selbsttest"
su -s /bin/bash mcadmin -c "systemctl --no-ask-password restart cron" >/dev/null 2>&1 \
  && echo "WARNUNG: mcadmin darf fremde Dienste steuern - Regel pruefen!" \
  || echo "OK: mcadmin darf keine fremden Dienste steuern"
sleep 2
fail2ban-client status cockpit >/dev/null && echo "OK: fail2ban-Jail cockpit aktiv"

echo
echo "Fertig. Aufruf: https://<Server-IP>:9090  ->  links \"Minecraft\""
echo "Fuer Zugriff von aussen im Router TCP 9090 freigeben."
if [ -n "$NEWPW" ]; then
  echo "Benutzer: mcadmin   Passwort: $NEWPW   (auch in /root/cockpit-mcadmin-passwort.txt)"
else
  echo "Benutzer mcadmin gab es schon - Passwort unveraendert (neu setzen: passwd mcadmin)."
fi

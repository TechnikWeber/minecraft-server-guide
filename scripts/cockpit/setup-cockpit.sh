#!/bin/bash
# Optional: Notfall-Weboberflaeche (Cockpit) fuer den Crossplay-Server.
#  - Cockpit (schlank: Uebersicht, Dienste, Logs) auf Port 9090
#  - gemeinsamer Benutzer "mcadmin", darf NUR minecraft-paper starten/stoppen/
#    neu starten und Logs lesen - keine Root-Rechte, kein SSH
#  - eigene Cockpit-Seite "Minecraft" mit Buttons, Status und Fehlern, dazu
#    Spieler, Whitelist, Freischalten, Spielregeln, Nachricht und Backups
#    ueber das Hilfsprogramm mc-admin (per pkexec, prueft jede Eingabe)
#  - RCON einschalten, falls noch aus (nur localhost, Zufallspasswort)
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
apt-get install -y -qq --no-install-recommends cockpit-ws cockpit-system cockpit-bridge polkitd pkexec >/dev/null
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
install -m 755 -o root -g root "$HERE/mc-admin" /usr/local/sbin/mc-admin
install -m 750 "$HERE/../common/mc-cmd" /usr/local/bin/mc-cmd

echo "==> RCON (fuer Spieler, Freischalten und Spielregeln)"
PROPS=/home/minecraft/paper/server.properties
RCON_NEU=false
if [ -f "$PROPS" ] && ! grep -q '^enable-rcon=true' "$PROPS"; then
  RCONPW=$(python3 -c "import secrets;print(secrets.token_urlsafe(24))")
  setprop() { if grep -q "^$1=" "$PROPS"; then sed -i "s|^$1=.*|$1=$2|" "$PROPS"; else echo "$1=$2" >> "$PROPS"; fi; }
  setprop enable-rcon true
  setprop rcon.port 25575
  setprop rcon.password "$RCONPW"
  setprop broadcast-rcon-to-ops false
  RCON_NEU=true
fi
[ -f "$PROPS" ] && chmod 640 "$PROPS"

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
su -s /bin/bash mcadmin -c "pkexec /usr/bin/id" >/dev/null 2>&1 \
  && echo "WARNUNG: mcadmin darf beliebige Programme als root starten - Regel pruefen!" \
  || echo "OK: mcadmin darf per pkexec nur mc-admin starten"
su -s /bin/bash mcadmin -c "pkexec /usr/local/sbin/mc-admin status" >/dev/null 2>&1 \
  && echo "OK: mc-admin laeuft fuer mcadmin" \
  || echo "WARNUNG: mc-admin laeuft fuer mcadmin nicht (polkit-Regel? pkexec installiert?)"
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
if [ "$RCON_NEU" = true ]; then
  echo
  echo "RCON wurde eingeschaltet. Damit Spieler, Freischalten und Spielregeln gehen,"
  echo "den Server einmal neu starten (Cockpit-Seite: Neu starten, oder: systemctl restart minecraft-paper)."
fi

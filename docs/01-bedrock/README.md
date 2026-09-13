# Bedrock-only-Server (Debian/Ubuntu, Proxmox LXC)

Voraussetzungen zuerst erledigen: **[docs/00-voraussetzungen.md](../00-voraussetzungen.md)** (Sizing, Zeitzone, Pakete, Repo klonen, Benutzer `minecraft`).

## Schritt 1 – Server herunterladen & entpacken

Der Download blockiert ohne Browser-User-Agent:

```bash
su - minecraft
mkdir -p ~/bedrock && cd ~/bedrock

curl -Lo bedrock-server.zip \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-1.26.14.1.zip

unzip bedrock-server.zip && rm bedrock-server.zip
chmod +x bedrock_server
echo "1.26.14.1" > ~/bedrock/.installed_version   # wird vom Auto-Update-Script verwendet
```

> Aktuelle Version + Downloadlink: [minecraft.net/download/server/bedrock](https://www.minecraft.net/en-us/download/server/bedrock). Schlägt der Download fehl: lokal herunterladen und per `scp` übertragen.

## Schritt 1b – (Optional) Bestehende Welt von einem alten Server übertragen

Ein Backup-Tarball (siehe Schritt 6) eignet sich perfekt als Transportmittel, weil er Welt + Konfiguration + OP-Rechte + Allowlist in einer Datei enthält:

```bash
# Auf dem ALTEN Server:
/usr/local/bin/mc-bedrock-backup.sh
ls /home/minecraft/backups/   # Dateinamen des neuesten Backups notieren

# Kopieren - auf dem PROXMOX-HOST, wenn beide LXC dort liegen (Standardfall):
pct pull <ALTE-CTID> /home/minecraft/backups/bedrock-backup-DATUM.tar.gz /tmp/bedrock-backup.tar.gz
pct push <NEUE-CTID> /tmp/bedrock-backup.tar.gz /root/bedrock-backup.tar.gz
rm /tmp/bedrock-backup.tar.gz

# Auf dem NEUEN Server (als root - nach Schritt 1 also erst exit):
systemctl stop minecraft-bedrock 2>/dev/null
tar -xzf /root/bedrock-backup.tar.gz -C /home/minecraft/bedrock
chown -R minecraft:minecraft /home/minecraft/bedrock
rm /root/bedrock-backup.tar.gz
```

Liegt der alte Server nicht auf demselben Proxmox-Host: per `scp` mit einem Benutzer übertragen, der sich per SSH anmelden darf — `minecraft` hat kein Passwort und geht dafür nicht.

> **Wichtig:** `level-name=` in `server.properties` muss **exakt** auf den Ordnernamen unter `worlds/` zeigen. Ein älteres Weltformat wird beim ersten Start automatisch (und unumkehrbar) aktualisiert — Original-Backup deshalb aufheben, bis alles läuft. Inventare/Fortschritt hängen an der Xbox-Identität der Spieler, nicht am Server — bleiben also erhalten.

## Schritt 2 – Erster Teststart

```bash
LD_LIBRARY_PATH=. ./bedrock_server
```

`Server started.` = alles korrekt, `Ctrl+C` zum Beenden. **Prozess vollständig beenden**, bevor systemd startet — sonst ist Port 19132 schon belegt.

## Schritt 3 – server.properties konfigurieren

```bash
exit   # zurueck zu root
nano /home/minecraft/bedrock/server.properties
```

| Einstellung | Standard (vanilla survival) | Kinderserver-Variante |
|---|---|---|
| `gamemode` | `survival` | `adventure` — siehe [Sicherheits-Stufen](../03-sicherheit-und-kinder/) |
| `difficulty` | `easy` oder `normal` | `peaceful` |
| `allow-cheats` | `false` | `true` (nötig, damit OPs `/gamemode` etc. nutzen können) |
| `force-gamemode` | `false` | `false` — **wichtig!** Sonst verliert ein individuell hochgestufter Spieler seinen Modus bei jedem Reconnect. Details: [Sicherheits-Stufen](../03-sicherheit-und-kinder/) |
| `max-players` | nach Bedarf | nach Bedarf |
| `online-mode` | `true` (Xbox-Auth, empfohlen) | `true` |
| `level-name` | Weltname = Ordnername unter `worlds/` | — |

Für das komplette Kinderserver-Profil (inkl. Freischaltung durch OP, Claims, CoreProtect-Äquivalent) siehe **[docs/03-sicherheit-und-kinder/kinderserver-profil.md](../03-sicherheit-und-kinder/kinderserver-profil.md)**.

> Bedrock hat kein Plugin-System — Rechteverwaltung läuft über `permissions.json` + die Server-Konsole, Schutz/Claims wie GriefPrevention gibt es hier nicht. Wer das braucht, ist im [Crossplay-Weg](../02-crossplay/) besser aufgehoben.

## Schritt 4 – systemd-Service

```bash
cd /opt/minecraft-server-guide
cp systemd/minecraft-bedrock.service /etc/systemd/system/minecraft-bedrock.service
systemctl daemon-reload
systemctl enable --now minecraft-bedrock
systemctl status minecraft-bedrock
```

`Port may be in use`? → `pkill -f bedrock_server`, dann erneut starten.

## Schritt 5 – Firewall & Port-Forwarding

```bash
ufw allow 22/tcp        # SSH zuerst, sonst sperrst du dich aus!
ufw allow 19132/udp     # Bedrock
ufw enable
```

Router: UDP, externer Port 19132 → interner Port 19132 → LXC-IP (`ip a | grep inet`). Der LXC braucht dafür eine **feste IP** (siehe [Weitere Empfehlungen](#weitere-empfehlungen)).

## Schritt 6 – Backup, ntfy, Auto-Update, Watchdog

Zentrale Config anlegen:

```bash
cd /opt/minecraft-server-guide
cp config/minecraft-bedrock.conf.example /etc/minecraft-guide.conf
nano /etc/minecraft-guide.conf   # NTFY_TOPIC auf einen eigenen, zufälligen Namen setzen!
chmod 600 /etc/minecraft-guide.conf
```

Scripts installieren:

```bash
cd /opt/minecraft-server-guide
install -m 750 scripts/common/mc-common.sh   /usr/local/bin/mc-common.sh
install -m 750 scripts/bedrock/mc-backup.sh   /usr/local/bin/mc-bedrock-backup.sh
install -m 750 scripts/bedrock/mc-update.sh   /usr/local/bin/mc-bedrock-update.sh
install -m 750 scripts/bedrock/mc-watchdog.sh /usr/local/bin/mc-bedrock-watchdog.sh
install -m 750 scripts/os/mc-os-update.sh     /usr/local/bin/mc-os-update.sh
cp config/logrotate-minecraft-guide /etc/logrotate.d/minecraft-guide
```

OS-Sicherheitsupdates einrichten (einmalig):

```bash
apt install -y unattended-upgrades
systemctl disable --now apt-daily-upgrade.timer   # das Anwenden steuert mc-os-update.sh per Cron, fuer saubere ntfy-Meldungen
```

Testen:

```bash
/usr/local/bin/mc-bedrock-backup.sh && ls -lh /home/minecraft/backups/
/usr/local/bin/mc-bedrock-update.sh
/usr/local/bin/mc-bedrock-watchdog.sh; echo "Exit: $?"   # sollte still sein
/usr/local/bin/mc-os-update.sh
```

ntfy-App (iOS/Android) installieren und dein `NTFY_TOPIC` abonnieren.

Cronjobs:

```bash
crontab -e
```

```cron
# Server-Überwachung alle 5 Minuten
*/5 * * * * /usr/local/bin/mc-bedrock-watchdog.sh >> /var/log/mc-watchdog.log 2>&1

# Tägliches Backup um 03:00 Uhr
0 3 * * * /usr/local/bin/mc-bedrock-backup.sh >> /var/log/mc-backup.log 2>&1

# OS-Sicherheitsupdates um 04:00 Uhr
0 4 * * * /usr/local/bin/mc-os-update.sh >> /var/log/mc-os-update.log 2>&1

# Tägliches Update (Bedrock-Version) um 04:30 Uhr
30 4 * * * /usr/local/bin/mc-bedrock-update.sh >> /var/log/mc-update.log 2>&1
```

> **Wie viele Backups bleiben?** `BACKUP_KEEP_DAYS=7` in der Config — alles Ältere wird gelöscht. Anpassbar.

## Weitere Empfehlungen

1. **Feste IP für den LXC.** Sonst zeigt das Port-Forwarding irgendwann ins Leere — Proxmox-Netzwerk auf static setzen oder DHCP-Reservierung auf die MAC-Adresse.
2. **DDNS für Freunde von außerhalb** (DuckDNS, FRITZ!Box MyFRITZ!), falls sich die öffentliche IP ändert.
3. **CGNAT/DS-Lite prüfen**, falls Port-Forwarding gar nicht ankommt: öffentliche IP mit der Router-WAN-IP vergleichen; `100.64.x.x` = CGNAT. Lösung: echte IPv4 beim Provider anfragen, IPv6 nutzen, oder Tailscale/ZeroTier.
4. **Proxmox-Snapshot als zweite Sicherheitsleine** vor größeren Eingriffen: `pct snapshot <CTID> vor-update`, im Notfall `pct rollback <CTID> vor-update`. Zusätzlich wöchentlichen `vzdump` einrichten.
5. **ntfy absichern**: zufälliger Topic-Name (schon in der Config so vorgesehen) oder Access-Token/eigener ntfy-Server — siehe [docs/06-wartung](../06-wartung/).
6. **Off-Site-Backup**: Backups liegen sonst nur auf demselben LXC. Per `rsync`/`rclone` nachts aufs NAS oder in die Cloud kopieren.
7. **Allowlist aktivieren**, wenn der Server aus dem Internet erreichbar ist — siehe [Sicherheits-Stufen](../03-sicherheit-und-kinder/).
8. **RAM-Schonung bei kleinem LXC**: `view-distance` (z.B. 8) und `tick-distance` (z.B. 4) in `server.properties` reduzieren.
9. **Konsolen-Clients (Xbox/PlayStation/Switch)** können keine eigene Server-IP eintragen — nur Handy/Tablet/Windows. Vorher einplanen, falls die Familie auf Konsole spielt.

Weiter: **[Sicherheits-Stufen & Kinderserver-Profil](../03-sicherheit-und-kinder/)** · **[Wartung & Troubleshooting](../06-wartung/)**

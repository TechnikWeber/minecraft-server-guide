# A – Bedrock-Server (Debian/Ubuntu, Proxmox LXC)

Die komplette Anleitung für einen **reinen Bedrock-Server**: Handy, Tablet und Windows-PC (Bedrock Edition) spielen gemeinsam auf einer Welt. Der Server ist leichtgewichtig, braucht wenig RAM und kommt ohne Java aus. Automatische Updates mit Rollback, tägliche Backups, Überwachung und ntfy-Benachrichtigungen sind von Anfang an dabei.

> Sollen auch Java-Spieler am PC mitspielen, oder braucht ihr Grundstücksschutz, `/home`, `/tpa` und das Zurückrollen von Schäden? Dann ist **[B – Crossplay](../b-crossplay/)** der richtige Weg — Bedrock hat kein Plugin-System.

Alle Befehle laufen **als root im LXC**. Wo der Benutzer `minecraft` gebraucht wird, steht `su - minecraft` im Befehlsblock.

## Inhalt

1. **[Vorbereitung](#teil-1--vorbereitung)** — LXC, Zeitzone, Pakete, Repo, Benutzer
2. **[Server installieren](#teil-2--server-installieren)** — Download, Teststart, server.properties, systemd, Firewall, OP-Rechte
3. **[Automatik](#teil-3--automatik)** — Config, Scripts, OS-Updates, Cronjobs
4. **[Sicherheit und Kinderserver](#teil-4--sicherheit-und-kinderserver)** — Allowlist, Gamemodes, Kinderserver-Profil, Gamerules
5. **[Wartung und Troubleshooting](#teil-5--wartung-und-troubleshooting)**
6. **[Weitere Empfehlungen](#weitere-empfehlungen)**

---

## Teil 1 – Vorbereitung

### Schritt 1 – LXC anlegen

| Ressource | Größe |
|---|---|
| RAM | mind. 1 GB, empfohlen 2 GB |
| Disk | mind. 2 GB, empfohlen 4 GB |
| CPU | 1 Kern reicht |

Als Template **Ubuntu 24.04** oder **Debian 13** — beide funktionieren gut:

| | Ubuntu 24.04 LTS („Noble") | Debian 13 („Trixie") |
|---|---|---|
| Support | regulär bis April 2029, mit kostenlosem Ubuntu Pro deutlich länger | ca. 5 Jahre |
| Mojang-Support | offiziell getestete Plattform (Bedrock verlangt Ubuntu 22.04+) | läuft ebenfalls, keine offizielle Mojang-Aussage |

In den Proxmox-Einstellungen:

- **„Start at boot"** aktivieren — automatischer Neustart nach einem Stromausfall
- **Feste IP** vergeben (Netzwerk auf static oder DHCP-Reservierung auf die MAC-Adresse) — sonst zeigt das Port-Forwarding irgendwann ins Leere
- `features: nesting=1` ist bei aktuellen Templates meist schon voreingestellt

Im Proxmox-LXC ist man standardmäßig root. Auf einem klassischen Ubuntu-Server außerhalb eines LXC zuerst `sudo -i`.

### Schritt 2 – Uhrzeit und Zeitzone prüfen

Falsche Zeitzone → Backups und Updates laufen zur falschen Zeit, Logs haben falsche Zeitstempel.

```bash
timedatectl
timedatectl set-timezone Europe/Berlin
```

Falls `System clock synchronized: no`:

```bash
apt install -y systemd-timesyncd
timedatectl set-ntp true
```

### Schritt 3 – System aktualisieren und Pakete installieren

```bash
apt update && apt upgrade -y
apt install -y curl unzip jq ufw logrotate git
```

`curl` und `unzip` für den Server-Download, `jq` für den Update-Check, `ufw` als Firewall, `logrotate` für die Logs, `git` für dieses Repo.

Dazu die Laufzeit-Bibliotheken des Bedrock-Servers — nur hier unterscheiden sich die Distros:

| Ubuntu 24.04 | Debian 13 |
|---|---|
| `apt install -y libcurl4t64 libssl3t64` | `apt install -y libcurl4 libssl3` |

> **Warum unterschiedliche Namen?** Ubuntu 24.04 hat im Zuge der 64-Bit-`time_t`-Umstellung einige Bibliotheken umbenannt. Meldet `apt` „Paket nicht gefunden", die Variante ohne `t64` probieren.

### Schritt 4 – Dieses Repo auf den Server holen

Scripts, systemd-Unit und Config-Vorlagen kommen direkt aus diesem Repo:

```bash
git clone https://github.com/TechnikWeber/minecraft-server-guide.git /opt/minecraft-server-guide
```

> **Später aktualisieren:** `cd /opt/minecraft-server-guide && git pull`, danach die Befehle aus [Schritt 14](#schritt-14--scripts-installieren) erneut ausführen — erst dann landen neue Script-Versionen in `/usr/local/bin`.

### Schritt 5 – Benutzer anlegen

Der Server läuft nie als root, sondern unter einem eigenen Systembenutzer:

```bash
useradd -m -r -s /bin/bash minecraft
```

> `-r` legt einen System-Benutzer ohne Passwort an. Einloggen geht nur **von root aus** mit `su - minecraft`.

---

## Teil 2 – Server installieren

### Schritt 6 – Server herunterladen und entpacken

Der Download blockiert ohne Browser-User-Agent:

```bash
su - minecraft
mkdir -p ~/bedrock && cd ~/bedrock

curl -Lo bedrock-server.zip \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-1.26.45.1.zip

unzip bedrock-server.zip && rm bedrock-server.zip
chmod +x bedrock_server
echo "1.26.45.1" > ~/bedrock/.installed_version   # wird vom Auto-Update-Script verwendet
exit   # zurueck zu root
```

> Aktuelle Version und Downloadlink: [minecraft.net/download/server/bedrock](https://www.minecraft.net/en-us/download/server/bedrock). Ist die Version hier schon älter, macht das nichts — das Auto-Update aus Teil 3 zieht nach. Schlägt der Download fehl: lokal herunterladen und per `scp` übertragen.

### Schritt 7 – Bestehende Welt übernehmen (optional)

Das Archiv des Backup-Scripts aus Teil 3 eignet sich perfekt als Transportmittel, weil es Welt, Konfiguration, OP-Rechte und Allowlist in einer Datei enthält:

```bash
# Auf dem ALTEN Server:
/usr/local/bin/mc-bedrock-backup.sh
ls /home/minecraft/backups/   # Dateinamen des neuesten Backups notieren

# Kopieren - auf dem PROXMOX-HOST, wenn beide LXC dort liegen (Standardfall):
pct pull <ALTE-CTID> /home/minecraft/backups/bedrock-backup-DATUM.tar.gz /tmp/bedrock-backup.tar.gz
pct push <NEUE-CTID> /tmp/bedrock-backup.tar.gz /root/bedrock-backup.tar.gz
rm /tmp/bedrock-backup.tar.gz

# Auf dem NEUEN Server:
rm -rf /home/minecraft/bedrock/worlds   # eine evtl. vorhandene Testwelt nicht mit der alten mischen
tar -xzf /root/bedrock-backup.tar.gz -C /home/minecraft/bedrock
chown -R minecraft:minecraft /home/minecraft/bedrock
rm /root/bedrock-backup.tar.gz
```

- **Alter Server ohne dieses Backup-Script:** dort den Server stoppen und im Server-Ordner dieselben Dateien von Hand packen: `tar -czf bedrock-backup-DATUM.tar.gz worlds server.properties permissions.json allowlist.json`
- **Alter Server nicht auf demselben Proxmox-Host:** per `scp` mit einem Benutzer übertragen, der sich per SSH anmelden darf — `minecraft` hat kein Passwort und geht dafür nicht.

> **Wichtig:** `level-name=` in `server.properties` muss **exakt** auf den Ordnernamen unter `worlds/` zeigen. Ein älteres Weltformat wird beim ersten Start automatisch und unumkehrbar aktualisiert — das Original-Backup deshalb aufheben, bis alles läuft.

### Schritt 8 – Erster Teststart

```bash
su - minecraft
cd ~/bedrock
LD_LIBRARY_PATH=. ./bedrock_server
```

`Server started.` = alles korrekt. Mit `stop` beenden, dann `exit` zurück zu root. **Prozess vollständig beenden**, bevor systemd startet — sonst ist Port 19132 schon belegt.

### Schritt 9 – server.properties konfigurieren

```bash
nano /home/minecraft/bedrock/server.properties
```

| Einstellung | Standard (Survival, offen) | Kinderserver |
|---|---|---|
| `gamemode` | `survival` | `adventure` |
| `difficulty` | `easy` oder `normal` | `peaceful` |
| `allow-cheats` | `false` | `true` — nötig, damit du als OP `/gamemode` und `/gamerule` nutzen kannst |
| `force-gamemode` | `false` | `false` — **wichtig**, sonst verliert ein freigeschalteter Spieler seinen Modus bei jedem Login |
| `allow-list` | `false` | nach Bedarf `true` |
| `max-players` | nach Bedarf | nach Bedarf |
| `online-mode` | `true` (Xbox-Anmeldung) | `true` |
| `level-name` | Weltname = Ordnername unter `worlds/` | — |

Hintergründe zu Allowlist, Gamemodes und dem kompletten Kinderserver-Profil: **[Teil 4](#teil-4--sicherheit-und-kinderserver)**.

### Schritt 10 – systemd-Service

```bash
cd /opt/minecraft-server-guide
cp systemd/minecraft-bedrock.service /etc/systemd/system/minecraft-bedrock.service
systemctl daemon-reload
systemctl enable --now minecraft-bedrock
systemctl status minecraft-bedrock
```

`Port may be in use`? → `pkill -f bedrock_server`, dann `systemctl restart minecraft-bedrock`.

### Schritt 11 – Firewall und Port-Forwarding

```bash
ufw allow 22/tcp        # SSH zuerst, sonst sperrst du dich aus!
ufw allow 19132/udp     # Bedrock
ufw enable
```

Router: **UDP** 19132 → 19132 auf die feste LXC-IP aus [Schritt 1](#schritt-1--lxc-anlegen) (`ip a | grep inet` zeigt sie). Kommt von außen nichts an: CGNAT prüfen, siehe [Weitere Empfehlungen](#weitere-empfehlungen).

### Schritt 12 – OP-Rechte vergeben

Der Dienst hat keine interaktive Konsole — für `op` den Server einmal von Hand starten:

```bash
touch /run/minecraft-bedrock.maintenance   # Watchdog pausieren (ab Teil 3 wichtig)
systemctl stop minecraft-bedrock
su - minecraft
cd ~/bedrock
LD_LIBRARY_PATH=. ./bedrock_server
```

Nach `Server started.` mit dem Spiel verbinden, dann in der Konsole (ohne `/`): `op DeinXboxGamertag`. Danach `stop`, `exit` und:

```bash
systemctl start minecraft-bedrock
rm /run/minecraft-bedrock.maintenance
```

Alternativ direkt in `/home/minecraft/bedrock/permissions.json` eintragen (Server vorher stoppen):

```json
[{ "permission": "operator", "xuid": "1234567890123456" }]
```

Die XUID steht im Log, sobald sich der Spieler einmal verbunden hat: `journalctl -u minecraft-bedrock | grep -i xuid`.

---

## Teil 3 – Automatik

Backup, Auto-Update mit Rollback, Watchdog und OS-Sicherheitsupdates — alles meldet sich per [ntfy](https://ntfy.sh) aufs Handy.

### Schritt 13 – Zentrale Config und ntfy

```bash
cd /opt/minecraft-server-guide
cp config/minecraft-bedrock.conf.example /etc/minecraft-guide.conf
nano /etc/minecraft-guide.conf   # NTFY_TOPIC auf einen eigenen, zufälligen Namen setzen!
chmod 600 /etc/minecraft-guide.conf
```

ntfy-App (iOS/Android) installieren und dein `NTFY_TOPIC` abonnieren. Warum der Name zufällig sein muss: [ntfy absichern](#ntfy-absichern).

### Schritt 14 – Scripts installieren

```bash
cd /opt/minecraft-server-guide
install -m 750 scripts/common/mc-common.sh    /usr/local/bin/mc-common.sh
install -m 750 scripts/bedrock/mc-backup.sh   /usr/local/bin/mc-bedrock-backup.sh
install -m 750 scripts/bedrock/mc-update.sh   /usr/local/bin/mc-bedrock-update.sh
install -m 750 scripts/bedrock/mc-watchdog.sh /usr/local/bin/mc-bedrock-watchdog.sh
install -m 750 scripts/os/mc-os-update.sh     /usr/local/bin/mc-os-update.sh
cp config/logrotate-minecraft-guide /etc/logrotate.d/minecraft-guide
```

### Schritt 15 – OS-Sicherheitsupdates einrichten

```bash
apt install -y unattended-upgrades
systemctl disable --now apt-daily-upgrade.timer   # das Anwenden steuert mc-os-update.sh per Cron, fuer saubere ntfy-Meldungen
```

Sicherheitsupdates sind auf beiden Distros ab Werk freigegeben. Prüfen: [Sicherheitsupdates prüfen](#sicherheitsupdates-prüfen).

### Schritt 16 – Testen

```bash
/usr/local/bin/mc-bedrock-backup.sh && ls -lh /home/minecraft/backups/
/usr/local/bin/mc-bedrock-update.sh
/usr/local/bin/mc-bedrock-watchdog.sh; echo "Exit: $?"   # sollte still sein
/usr/local/bin/mc-os-update.sh
```

### Schritt 17 – Cronjobs

```bash
crontab -e
```

```cron
# Watchdog alle 5 Minuten
*/5 * * * * /usr/local/bin/mc-bedrock-watchdog.sh >> /var/log/mc-watchdog.log 2>&1

# Backup um 03:00
0 3 * * * /usr/local/bin/mc-bedrock-backup.sh >> /var/log/mc-backup.log 2>&1

# OS-Sicherheitsupdates um 04:00
0 4 * * * /usr/local/bin/mc-os-update.sh >> /var/log/mc-os-update.log 2>&1

# Bedrock-Update um 04:30 (Neustart nur, wenn es eine neue Version gibt)
30 4 * * * /usr/local/bin/mc-bedrock-update.sh >> /var/log/mc-update.log 2>&1
```

### Was automatisch läuft und was nicht

| Aufgabe | Automatisch? | Details |
|---|---|---|
| Watchdog | ✅ alle 5 Minuten | Startet einen abgestürzten Server neu, meldet nur Zustandswechsel |
| Backup | ✅ täglich 03:00 | Welt, `server.properties`, `permissions.json`, `allowlist.json` · aufbewahrt 7 Tage (`BACKUP_KEEP_DAYS` in der Config) |
| OS-Sicherheitsupdates | ✅ täglich 04:00 | Neustart wird nur **gemeldet**, nicht erzwungen |
| Bedrock-Version | ✅ täglich 04:30 | Über die Mojang-API, vorher Backup und Snapshot, bei Fehlstart automatischer Rollback |
| Distro-Wechsel, Proxmox-Host | ❌ manuell | siehe [Was die Automatik nicht abdeckt](#was-die-automatik-nicht-abdeckt) |

---

## Teil 4 – Sicherheit und Kinderserver

Drei Stufen, die sich kombinieren lassen: wer überhaupt reinkommt, was ein Spieler darf, und was hilft, wenn doch etwas schiefgeht. Standard dieser Anleitung ist **offen und Survival**; für einen Kinderserver gilt das [Kinderserver-Profil](#kinderserver-profil) weiter unten.

### Stufe 1 – Wer darf rein: Allowlist

Standardmäßig **aus** — jeder mit der Adresse kann beitreten. Sinnvoll, sobald der Server aus dem Internet erreichbar ist:

1. `allow-list=true` in `server.properties`
2. Spieler in `/home/minecraft/bedrock/allowlist.json` eintragen:

   ```json
   [
     { "ignoresPlayerLimit": false, "name": "Gamertag1" },
     { "ignoresPlayerLimit": false, "name": "Gamertag2" }
   ]
   ```

3. `systemctl restart minecraft-bedrock`

### Stufe 2 – Was darf man: Gamemode und Freischaltung

| Gamemode | Bauen/abbauen? | Items benutzen/aufheben? | Fliegen/durch Wände? |
|---|---|---|---|
| `survival` | ja | ja | nein |
| `creative` | ja, unbegrenzt | ja | ja |
| `adventure` | **nein** | ja (Kisten, Türen, Hebel) | nein |
| `spectator` | **nein** | **nein, gar keine Interaktion** | ja, durch Wände |

**Adventure oder Spectator?** Beide verhindern Bauen und Abbauen. In **Adventure** bewegt man sich normal und kann Dinge benutzen — das fühlt sich für Kinder wie „richtig spielen" an. In **Spectator** fliegt man geisterhaft durch die Welt und kann nichts anfassen — die strengste Stufe, eher zum Zuschauen. Für die meisten Fälle ist **Adventure** der bessere Standard.

**Das Prinzip „kontrolliertes Bauen":** `gamemode=adventure` als Standard, `force-gamemode=false`, und wer bauen darf, wird **einzeln** freigeschaltet — ingame als OP (dafür `allow-cheats=true`):

- Freischalten: `/gamemode creative Gamertag`
- Zurücknehmen: `/gamemode adventure Gamertag`

> **Warum `force-gamemode=false` entscheidend ist:** Dann **bleibt** ein freigeschalteter Spieler in seinem Modus, auch nach dem nächsten Login oder einem Neustart. Mit `true` wird jeder bei jedem Login auf den Standard zurückgesetzt — die Freischaltung wäre jedes Mal weg.

### Stufe 3 – Wenn doch etwas passiert

Bedrock hat kein Plugin-System — Grundstücksschutz und das gezielte Zurückrollen einzelner Schäden gibt es hier nicht (dafür: [B – Crossplay](../b-crossplay/) mit GriefPrevention und CoreProtect). Die Sicherheitsleinen sind:

- **Tägliches Backup** aus Teil 3 — so geht's: [Backup zurückspielen](#backup-zurückspielen). Dabei geht alles seit dem Backup verloren, nicht nur der Schaden.
- **Proxmox-Snapshot** vor größeren Eingriffen: `pct snapshot <CTID> vor-aenderung`, im Notfall `pct rollback <CTID> vor-aenderung`.

### Kinderserver-Profil

Peaceful, niemand baut ohne Freischaltung, dazu ruhige Gamerules. Auf Bedrock trägt der **Adventure-Standard** den ganzen Schutz — für Grundstücksschutz zwischen Kindern lohnt sich [B – Crossplay](../b-crossplay/).

**server.properties** ([Schritt 9](#schritt-9--serverproperties-konfigurieren)):

| Einstellung | Wert | Warum |
|---|---|---|
| `gamemode` | `adventure` | Niemand kann bauen oder abbauen, bevor du es erlaubst |
| `difficulty` | `peaceful` | Keine Monster, kein Hunger |
| `force-gamemode` | `false` | Freigeschaltete Kinder **bleiben** in ihrem Modus |
| `allow-cheats` | `true` | Nötig für `/gamemode` und `/gamerule` |
| `online-mode` | `true` | Xbox-Anmeldung — nicht abschalten |

**Freischaltung:** Ein Kind darf bauen → `/gamemode creative NameDesKindes`. Zurück auf „nur anschauen" → `/gamemode adventure NameDesKindes`. Lieber echtes Überleben statt Creative: `/gamemode survival NameDesKindes` plus die Gamerule `keepinventory` (unten), damit ein Tod nicht alle Sachen kostet.

#### Gamerules

Ingame als OP, einmal pro Welt. Gamerules werden **in der Welt** gespeichert — sie überstehen Neustarts und Updates und sind im Backup enthalten. `difficulty=peaceful` verhindert schon Monster und Hunger; optional zusätzlich:

| Befehl | Wirkung |
|---|---|
| `/gamerule dodaylightcycle false` + `/time set day` | Immer Tag |
| `/gamerule doweathercycle false` + `/weather clear` | Immer klares Wetter |
| `/gamerule domobspawning false` | Keine Tiere und Monster |
| `/gamerule mobgriefing false` | Mobs verändern keine Blöcke |
| `/gamerule pvp false` | Kinder können sich nicht gegenseitig verletzen |
| `/gamerule falldamage false` · `/gamerule firedamage false` | Kein Fall- und Feuerschaden |
| `/gamerule tntexplodes false` | TNT explodiert nicht |
| `/gamerule keepinventory true` | Items bleiben beim Tod erhalten (nur in Survival relevant) |
| `/gamerule showcoordinates true` | Koordinaten oben links — hilft Kindern bei der Orientierung |

---

## Teil 5 – Wartung und Troubleshooting

**Faustregel:** Im Alltag musst du nichts tun. Aufmerksam werden solltest du nur, wenn eine **ntfy-Meldung** kommt — die Nachricht sagt jeweils, was zu prüfen ist.

### Server steuern

```bash
systemctl start|stop|restart|status minecraft-bedrock
journalctl -u minecraft-bedrock -n 50            # letzte 50 Log-Einträge
journalctl -u minecraft-bedrock -f --no-pager    # Live-Log, Ctrl+C zum Beenden
```

> Ein nur mit `systemctl stop` angehaltener Server wird vom Watchdog nach spätestens 5 Minuten wieder gestartet. Für kurze Arbeiten das [Wartungs-Flag](#wartungs-flag) setzen, für längere Pausen die Watchdog-Zeile in `crontab -e` auskommentieren.

### Wartungs-Flag

```bash
touch /run/minecraft-bedrock.maintenance   # Watchdog pausieren
rm /run/minecraft-bedrock.maintenance      # wieder freigeben
```

Solange das Flag existiert, greift der Watchdog nicht ein. Es gilt maximal 60 Minuten, danach räumt der Watchdog es selbst weg — bei längeren Arbeiten zwischendurch erneut `touch`. Backup und Update setzen das Flag automatisch.

### Automatik von Hand anstoßen

| Befehl | Wirkung |
|---|---|
| `/usr/local/bin/mc-bedrock-backup.sh` | Backup sofort erstellen |
| `/usr/local/bin/mc-bedrock-update.sh` | Update sofort prüfen und ggf. durchführen |
| `/usr/local/bin/mc-bedrock-watchdog.sh` | Überwachung sofort ausführen |
| `/usr/local/bin/mc-os-update.sh` | OS-Sicherheitsupdates sofort ausführen |

### Backup zurückspielen

```bash
touch /run/minecraft-bedrock.maintenance
systemctl stop minecraft-bedrock
ls -lh /home/minecraft/backups/          # gewünschtes Backup aussuchen
rm -rf /home/minecraft/bedrock/worlds    # nicht mit dem Backup mischen
tar -xzf /home/minecraft/backups/bedrock-backup-DATUM.tar.gz -C /home/minecraft/bedrock
chown -R minecraft:minecraft /home/minecraft/bedrock
systemctl start minecraft-bedrock
rm /run/minecraft-bedrock.maintenance
```

Wer unsicher ist, sichert vorher noch den aktuellen Stand mit `/usr/local/bin/mc-bedrock-backup.sh`.

### Welt zurücksetzen oder neu würfeln

**Immer zuerst ein Backup:** `/usr/local/bin/mc-bedrock-backup.sh`

**Komplett neue Welt, alte löschen:**

```bash
touch /run/minecraft-bedrock.maintenance
systemctl stop minecraft-bedrock
rm -rf "/home/minecraft/bedrock/worlds/Bedrock level"   # Weltname = level-name aus server.properties
systemctl start minecraft-bedrock
rm /run/minecraft-bedrock.maintenance
```

**Neue Welt, alte behalten:** `level-name` in `server.properties` auf einen neuen Namen ändern und neu starten. Die alte Welt bleibt unter ihrem Ordnernamen erhalten und lässt sich durch Zurücksetzen des Namens jederzeit wieder aktivieren.

**Bestimmten Seed statt Zufall:** vor dem Start `level-seed=<Wert>` setzen.

### Sicherheitsupdates prüfen

Beide Distros geben Sicherheitsupdates für `unattended-upgrades` ab Werk frei. Kontrolle:

```bash
unattended-upgrade --dry-run -d 2>&1 | grep -i 'allowed origins'
```

Die Zeile muss `-security` (Ubuntu) bzw. `Debian-Security` (Debian) enthalten. Was nachts installiert wurde, steht in `/var/log/mc-os-update.log`.

### Was die Automatik nicht abdeckt

| Aufgabe | Wie oft | Was tun |
|---|---|---|
| **Distro-Wechsel** (Ubuntu 24.04 → 26.04, Debian 13 → 14) | alle paar Jahre | Bewusst und mit Proxmox-Snapshot vorher (`pct snapshot <CTID> vor-upgrade`); bei Ubuntu über `do-release-upgrade`, bei Debian über die Paketquellen auf den neuen Codenamen. |
| **Support-Ende der Distro** | nach ca. 5 Jahren | Ubuntu: **Ubuntu Pro** ist für Privatnutzung kostenlos und verlängert die Sicherheitsupdates um Jahre. Debian: Die LTS-Phase läuft automatisch über die normalen Paketquellen; danach gibt es nur noch kostenpflichtiges ELTS — rechtzeitig auf die nächste Version wechseln. |
| **Proxmox-Host-Updates** | gelegentlich | Laufen auf dem Host, nicht im LXC. |
| **Kernel** | – | Kommt vom Host — im LXC nichts zu tun. |

### ntfy-Meldungen

| Titel | Bedeutung | Handlungsbedarf |
|---|---|---|
| `Bedrock: Update erfolgreich` | Neue Version installiert, Server läuft. | Nein |
| `Bedrock: Update-Check fehlgeschlagen` | Mojang-API nicht erreichbar, Server läuft unverändert. | Nur wenn es sich wiederholt |
| `Bedrock: Update-Download fehlgeschlagen` | Download defekt, Server läuft unverändert. | Nur wenn es sich wiederholt |
| `Bedrock: Update abgebrochen` | Backup oder Snapshot vor dem Update fehlgeschlagen, nichts geändert. | Speicherplatz prüfen: `df -h` |
| `Bedrock: Update fehlgeschlagen (Rollback)` | Neue Version startete nicht, alte läuft wieder. | Bei Gelegenheit Logs ansehen |
| `Bedrock: KRITISCH - manueller Eingriff noetig` | Update **und** Rollback gescheitert. | **Ja, sofort** — Befehle stehen in der Nachricht |
| `Bedrock: Backup fehlgeschlagen` | Das nächtliche Backup ging schief. | `/var/log/mc-backup.log` und `df -h` prüfen |
| `Bedrock: Server war down - neu gestartet` | Watchdog hat den Server wieder hochgefahren. | Nein, im Auge behalten falls häufig |
| `Bedrock: Server DOWN` | Server weg, automatischer Neustart hat nicht geholfen. | **Ja** — Befehle stehen in der Nachricht |
| `Bedrock: Server wieder online` | Nach einem Ausfall wieder erreichbar. | Nein |
| `Host: Sicherheitsupdates installiert` | Sicherheitsupdates eingespielt. | Nur falls ein Neustart-Hinweis dabeisteht |
| `Host: Neustart empfohlen` | Bibliotheken aktualisiert. | Bei Gelegenheit `reboot` |
| `Host: OS-Update Problem` | Sicherheitsupdates liefen nicht sauber durch. | Befehle stehen in der Nachricht |

### ntfy absichern

Ein öffentliches `ntfy.sh`-Topic kann von **jedem** gelesen und beschrieben werden, der den Namen kennt. Absicherungsstufen:

1. **Zufälliger Topic-Name** — Minimum, in der Config-Vorlage schon so vorgesehen.
2. **Access-Token:** `curl -H "Authorization: Bearer tk_..." ...` in `mc_notify()` ergänzen (`scripts/common/mc-common.sh`).
3. **Eigener ntfy-Server** statt `ntfy.sh`.

### Troubleshooting

| Problem | Lösung |
|---|---|
| `Port may be in use` beim Start | `pkill -f bedrock_server`, dann `systemctl restart minecraft-bedrock` |
| Von außen kommt niemand rein | Port-Forwarding **UDP** 19132 und feste IP prüfen; CGNAT siehe [Weitere Empfehlungen](#weitere-empfehlungen) |
| Konsole (Xbox/PlayStation/Switch) findet den Server nicht | Konsolen können keine eigene Server-Adresse eintragen — siehe [Weitere Empfehlungen](#weitere-empfehlungen) |
| Update-Meldung kommt jede Nacht wieder | `/var/log/mc-update.log` und `journalctl -u minecraft-bedrock -n 80` ansehen |
| `apt`-Befehl meldet „could not get lock" | Gerade läuft ein anderer apt-Vorgang (z.B. `mc-os-update.sh` oder der tägliche Paketlisten-Abgleich) — kurz warten und erneut versuchen |
| `journalctl`-Zeile endet mit `>` | Nur abgeschnitten (Pager) — `q` zum Verlassen, oder `--no-pager` anhängen |

---

## Weitere Empfehlungen

1. **DDNS für Freunde von außerhalb** (DuckDNS, FRITZ!Box MyFRITZ!), falls sich die öffentliche IP ändert.
2. **CGNAT/DS-Lite prüfen**, falls Port-Forwarding gar nicht ankommt: öffentliche IP mit der WAN-IP des Routers vergleichen; `100.64.x.x` = CGNAT. Lösung: echte IPv4 beim Provider anfragen, IPv6 nutzen, oder Tailscale/ZeroTier.
3. **Proxmox-Snapshot als zweite Sicherheitsleine** vor größeren Eingriffen: `pct snapshot <CTID> vor-update`, im Notfall `pct rollback <CTID> vor-update`. Zusätzlich einen wöchentlichen `vzdump` einrichten.
4. **Off-Site-Backup:** Die Backups liegen sonst nur im selben LXC. Per `rsync`/`rclone` nachts aufs NAS oder in die Cloud kopieren.
5. **RAM sparen bei kleinem LXC:** `view-distance` (z.B. 8) und `tick-distance` (z.B. 4) in `server.properties` reduzieren.
6. **Konsolen-Clients (Xbox/PlayStation/Switch)** können keine eigene Server-Adresse eintragen — nur Handy, Tablet und Windows. Vorher einplanen, falls die Familie auf Konsole spielt.

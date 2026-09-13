# B – Crossplay-Server: Java + Bedrock + Plugins (Debian/Ubuntu, Proxmox LXC)

Die komplette Anleitung für einen **Crossplay-Server**: Java-Spieler am PC und Bedrock-Spieler auf Handy, Tablet und Windows spielen gemeinsam auf einer Welt. Dazu ein durchdachter Plugin-Stack für Komfort, Rechte und Schutz. Automatische Updates mit Rollback, tägliche Backups, Überwachung und ntfy-Benachrichtigungen sind von Anfang an dabei.

**Der Stack:** PaperMC 26.1.2 · Geyser + Floodgate (Zugang für Bedrock) · ViaVersion/ViaBackwards (andere Java-Versionen) · LuckPerms · Vault · EssentialsX · CoreProtect · GriefPrevention · Chunky

> **Die wichtigste Regel dieses Wegs: Geyser und die Plugins sind der limitierende Faktor.** Wir nutzen Paper **26.1.2**, nicht die neueste Version 26.2 — es ist die höchste Version, die Geyser **und** alle Plugins offiziell unterstützen (EssentialsX und CoreProtect haben für 26.2 noch kein Release). Reihenfolge bei jedem größeren Sprung: **erst prüfen, ob Geyser und alle Plugins die Zielversion können, dann Paper.** Java-Clients mit neueren Versionen können sich trotzdem verbinden — dafür sorgen ViaVersion und ViaBackwards.

> Nur Bedrock-Geräte, keine Plugins nötig? Dann reicht der schlankere Weg **[A – Bedrock](../a-bedrock/)**.

Alle Befehle laufen **als root im LXC**. Wo der Benutzer `minecraft` gebraucht wird, steht `su - minecraft` im Befehlsblock.

## Inhalt

1. **[Vorbereitung](#teil-1--vorbereitung)** — LXC, Zeitzone, Pakete, Java 25, Repo, Benutzer
2. **[Server installieren](#teil-2--server-installieren)** — Paper, Geyser, Plugins, Konfiguration, systemd, Firewall, OP-Rechte, Chunky
3. **[Automatik](#teil-3--automatik)** — Config, Scripts, OS-Updates, Cronjobs
4. **[Sicherheit und Kinderserver](#teil-4--sicherheit-und-kinderserver)** — Whitelist, Gamemodes, Claims, Kinderserver-Profil, Gamerules, Starter-Kit
5. **[Plugins und Befehle](#teil-5--plugins-und-befehle)**
6. **[Wartung und Troubleshooting](#teil-6--wartung-und-troubleshooting)**
7. **[Erweiterungen](#teil-7--erweiterungen)**
8. **[Weitere Empfehlungen](#weitere-empfehlungen)**

Zum Weitergeben an die Spieler: **[Spieler-Anleitung](spieler-anleitung.md)** · **[dieselbe für Discord](spieler-anleitung-discord.md)**

---

## Teil 1 – Vorbereitung

### Schritt 1 – LXC anlegen

| Ressource | Größe |
|---|---|
| RAM | mind. 6 GB, empfohlen 8 GB |
| Disk | mind. 12 GB (die CoreProtect-Datenbank wächst) |
| CPU | mind. 2 Kerne, empfohlen 4 |

> **Warum so viel?** Paper, Geyser, Floodgate, ViaVersion und alle Plugins laufen zusammen in **einer** Java-VM.

Als Template **Ubuntu 24.04** oder **Debian 13** — beide funktionieren gut:

| | Ubuntu 24.04 LTS („Noble") | Debian 13 („Trixie") |
|---|---|---|
| Support | regulär bis April 2029, mit kostenlosem Ubuntu Pro deutlich länger | ca. 5 Jahre |

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
apt install -y curl wget unzip jq file ufw logrotate git ca-certificates gnupg
```

`curl` und `wget` für Downloads, `unzip` und `file` zum Prüfen der JARs, `jq` für den Update-Check, `ufw` als Firewall, `logrotate` für die Logs, `git` für dieses Repo, `ca-certificates` und `gnupg` für das Java-Repository. Auf beiden Distros identisch.

### Schritt 4 – Java 25 installieren

Paper 26.1.2 braucht **Java 25** (Pflicht ab Minecraft 26.1). Weder Ubuntu 24.04 noch Debian 13 haben das im Standard-Repository — daher über das Adoptium-Repository (Eclipse Temurin). Der Block ist auf beiden Distros identisch, weil er den Codenamen automatisch ausliest:

```bash
wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | \
  gpg --dearmor -o /usr/share/keyrings/adoptium.gpg

echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | \
  tee /etc/apt/sources.list.d/adoptium.list

apt update
apt install -y temurin-25-jre
java -version
```

Die Ausgabe sollte `openjdk version "25"` zeigen.

### Schritt 5 – Dieses Repo auf den Server holen

Scripts, systemd-Unit und Config-Vorlagen kommen direkt aus diesem Repo:

```bash
git clone https://github.com/TechnikWeber/minecraft-server-guide.git /opt/minecraft-server-guide
```

> **Später aktualisieren:** `cd /opt/minecraft-server-guide && git pull`, danach die Befehle aus [Schritt 20](#schritt-20--scripts-installieren) erneut ausführen — erst dann landen neue Script-Versionen in `/usr/local/bin`.

### Schritt 6 – Benutzer anlegen

Der Server läuft nie als root, sondern unter einem eigenen Systembenutzer:

```bash
useradd -m -r -s /bin/bash minecraft
```

> `-r` legt einen System-Benutzer ohne Passwort an. Einloggen geht nur **von root aus** mit `su - minecraft`.

---

## Teil 2 – Server installieren

### Schritt 7 – PaperMC herunterladen

```bash
mkdir -p /home/minecraft/paper && cd /home/minecraft/paper
wget -O paper.jar \
  "https://fill-data.papermc.io/v1/objects/1d70b1dab9cf4a6de615209a536f3a45a2186240253c428213ce2188ab95e5f7/paper-26.1.2-74.jar"
chown -R minecraft:minecraft /home/minecraft/paper
```

Die Datei sollte 50–60 MB groß sein. Falls der Link abläuft: [papermc.io/downloads/paper](https://papermc.io/downloads/paper) → Version **26.1.2** wählen → Download-Link kopieren. Ein älterer Build ist kein Problem — das Auto-Update aus Teil 3 zieht nach.

### Schritt 8 – EULA und Teststart

```bash
su - minecraft
cd ~/paper
java -Xms2G -Xmx4G -jar paper.jar --nogui
```

Der erste Start stoppt mit einem EULA-Hinweis. `nano eula.txt` → `eula=true`, speichern, erneut starten. Bei `Done (...)` in der Konsole `stop` eingeben. Als `minecraft` geht es direkt mit Schritt 9 weiter.

### Schritt 9 – Geyser, Floodgate, ViaVersion und ViaBackwards

```bash
cd ~/paper/plugins

curl -Lo Geyser-Spigot.jar \
  "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
curl -Lo floodgate-spigot.jar \
  "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"

# ViaVersion/ViaBackwards: fester Hangar-CDN-Link mit Versionsnummer ist die
# einzig verlaessliche Methode - GitHub-latest-Links liefern oft nur eine
# Fehlerseite statt der JAR. Aktuelle Version: hangar.papermc.io/ViaVersion
wget -O ViaVersion.jar \
  "https://hangarcdn.papermc.io/plugins/ViaVersion/ViaVersion/versions/5.11.0/PAPER/ViaVersion-5.11.0.jar"
wget -O ViaBackwards.jar \
  "https://hangarcdn.papermc.io/plugins/ViaVersion/ViaBackwards/versions/5.11.0/PAPER/ViaBackwards-5.11.0.jar"

ls -lh *.jar && file *.jar   # "Java archive data (JAR)" oder "Zip archive data" - nie HTML/ASCII text
```

> ViaVersion und ViaBackwards **immer in derselben Version** und aus demselben Channel (Release) ziehen, nie mischen.

### Schritt 10 – Plugin-Stack installieren

Weiter als `minecraft` im `plugins`-Ordner. Was die Plugins tun und woher neuere Versionen kommen: **[Teil 5](#teil-5--plugins-und-befehle)**.

```bash
# LuckPerms, Vault, EssentialsX (+Spawn +Chat), CoreProtect, GriefPrevention, Chunky
# Feste Links mit Versionsnummer, alle fuer Paper 26.1.2 geprueft (Stand September 2026).
wget -O LuckPerms.jar        "https://cdn.modrinth.com/data/Vebnzrzj/versions/b0mk8uS6/LuckPerms-Bukkit-5.5.71.jar"
wget -O Vault.jar            "https://github.com/MilkBowl/Vault/releases/download/1.7.3/Vault.jar"
wget -O CoreProtect.jar      "https://cdn.modrinth.com/data/Lu3KuzdV/versions/Kma0kBsY/CoreProtect-CE-24.0.jar"
wget -O GriefPrevention.jar  "https://cdn.modrinth.com/data/O4o4mKaq/versions/dGfCZHqk/GriefPrevention.jar"
wget -O Chunky.jar           "https://cdn.modrinth.com/data/fALzjamp/versions/MdY6JATr/Chunky-Bukkit-1.5.3.jar"
wget -O EssentialsX.jar      "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsX-2.22.0.jar"
wget -O EssentialsXSpawn.jar "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsXSpawn-2.22.0.jar"
wget -O EssentialsXChat.jar  "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsXChat-2.22.0.jar"

ls -lh ~/paper/plugins && file ~/paper/plugins/*.jar
exit   # zurueck zu root
```

**Jede** Datei muss als `Java archive data (JAR)` oder `Zip archive data` erkannt werden (eine JAR ist ein ZIP). Steht dort `HTML document` oder `ASCII text`, war der Download eine Fehlerseite. Die Größe sagt wenig: EssentialsXSpawn hat nur rund 20 KB, EssentialsX knapp 5 MB.

> WorldEdit und WorldGuard sind **bewusst nicht** im Standard-Stack — GriefPrevention deckt Claims inklusive Spawn-Schutz ab. Als Ausbaustufe: [Teil 7](#teil-7--erweiterungen).

### Schritt 11 – server.properties konfigurieren

```bash
nano /home/minecraft/paper/server.properties
```

| Einstellung | Standard (Survival, offen) | Kinderserver |
|---|---|---|
| `gamemode` | `survival` | `adventure` |
| `difficulty` | `easy` oder `normal` | `peaceful` |
| `force-gamemode` | `false` | `false` — **wichtig**, sonst verliert ein freigeschalteter Spieler seinen Modus bei jedem Login |
| `white-list` | `false` | nach Bedarf `true` |
| `online-mode` | `true` — **nicht ändern!** | `true` |
| `enforce-secure-profile` | **`false`** — sonst werden Bedrock-Spieler beim Chatten gekickt | `false` |
| `motd` | Servername in der Java-Serverliste | wie Standard |
| `max-players` | nach Bedarf | nach Bedarf |

> **`enforce-secure-profile=false` ist bei Crossplay Pflicht.** Die Einstellung verlangt kryptografisch signierte Chat-Nachrichten über Mojangs Java-Anmeldung. Bedrock-Spieler kommen über Floodgate mit ihrem Xbox-Konto — sie können das technisch nicht liefern und würden beim ersten Chatversuch rausgeworfen. `false` ist die offizielle Floodgate-Empfehlung für private Crossplay-Server.

Hintergründe zu Whitelist, Gamemodes und dem kompletten Kinderserver-Profil: **[Teil 4](#teil-4--sicherheit-und-kinderserver)**.

### Schritt 12 – Einmal starten, damit die Plugins ihre Configs anlegen

```bash
su - minecraft
cd ~/paper
java -Xms2G -Xmx4G -jar paper.jar --nogui
```

Das Log sollte u.a. zeigen: `[LuckPerms] Successfully enabled`, `[CoreProtect] Enabled`, `[GriefPrevention] ... enabled`, `[Essentials] Enabled`, `[floodgate] ... Floodgate`, `[Geyser-Spigot] Started Geyser on UDP port 19132`, `[ViaVersion] Loading ViaVersion`. Dann `stop` und `exit`.

> Stürzt Geyser mit `ExceptionInInitializerError` ab: Die Paper-Version ist zu neu für Geyser — auf der gepinnten Version bleiben, bis Geyser nachzieht.

### Schritt 13 – Geyser konfigurieren

```bash
nano /home/minecraft/paper/plugins/Geyser-Spigot/config.yml
```

```yaml
motd:
  primary-motd: DeinServerName
gameplay:
  server-name: DeinServerName
java:
  auth-type: floodgate   # <- der wichtigste Punkt
```

> Drei Felder beschreiben denselben Server: `motd=` in `server.properties` (Java-Serverliste), `motd.primary-motd` (Bedrock-Serverliste) und `gameplay.server-name` (Bedrock ingame) — überall denselben Namen setzen.

### Schritt 14 – Floodgate-Kontoverknüpfung

Optional, aber empfohlen: Damit teilen Java- und Bedrock-Konto eines Spielers dieselbe Identität (Rechte, Claims, Inventar). Ohne Verknüpfung sind es **zwei verschiedene Spieler** — Rechte, Claims und Homes müssten doppelt vergeben werden.

Für die Verknüpfung auf dem eigenen Server braucht Floodgate eine Datenbank-Erweiterung — sie kommt in den Floodgate-Ordner:

```bash
cd /home/minecraft/paper/plugins/floodgate
wget -O floodgate-sqlite-database.jar \
  "https://download.geysermc.org/v2/projects/floodgatedb/versions/latest/builds/latest/downloads/sqlite"
chown minecraft:minecraft floodgate-sqlite-database.jar
nano config.yml
```

```yaml
player-link:
  enabled: true
  require-link: false
  enable-own-linking: true   # <- ohne das gibt es /linkaccount nicht
  allowed: true
  type: sqlite
```

**Verknüpfen im Spiel:** mit dem Java-Client einloggen → im Java-Chat `/linkaccount BedrockName` (zeigt einen Code) → mit dem Bedrock-Client einloggen (erscheint als `.BedrockName`) → im Bedrock-Chat `/linkaccount JavaName Code`. Der Bedrock-Client wird danach einmal gekickt, beim nächsten Login sind beide Konten verknüpft.

### Schritt 15 – systemd-Service

```bash
cd /opt/minecraft-server-guide
cp systemd/minecraft-paper.service /etc/systemd/system/minecraft-paper.service
nano /etc/systemd/system/minecraft-paper.service   # -Xmx anpassen: LXC-RAM minus ca. 1,5 GB
systemctl daemon-reload
systemctl enable --now minecraft-paper
journalctl -u minecraft-paper -n 50
```

Nach etwa einer Minute sollte im Log `Done (...)` stehen.

### Schritt 16 – Firewall und Port-Forwarding

```bash
ufw allow 22/tcp        # SSH zuerst, sonst sperrst du dich aus!
ufw allow 25565/tcp     # Java
ufw allow 19132/udp     # Bedrock ueber Geyser
ufw enable
```

Router: **TCP** 25565 → 25565 und **UDP** 19132 → 19132, beide auf die feste LXC-IP aus [Schritt 1](#schritt-1--lxc-anlegen) (`ip a | grep inet` zeigt sie). Kommt von außen nichts an: CGNAT prüfen, siehe [Weitere Empfehlungen](#weitere-empfehlungen).

### Schritt 17 – OP-Rechte vergeben

Der Dienst hat keine interaktive Konsole — für `op` den Server einmal von Hand starten:

```bash
touch /run/minecraft-paper.maintenance   # Watchdog pausieren (ab Teil 3 wichtig)
systemctl stop minecraft-paper
su - minecraft
cd ~/paper
java -Xms2G -Xmx4G -jar paper.jar --nogui
```

Nach `Done (...)` in der Konsole (ohne `/`): `op DeinJavaName`. Danach `stop`, `exit` und:

```bash
systemctl start minecraft-paper
rm /run/minecraft-paper.maintenance
```

> Java-Namen lassen sich auch opsen, bevor der Spieler je online war. Bedrock-Spieler ohne Kontoverknüpfung haben einen Punkt vor dem Namen (`op .Gamertag`) und müssen den Server vorher einmal betreten haben. Mit Verknüpfung ([Schritt 14](#schritt-14--floodgate-kontoverknüpfung)) reicht der Java-Name.

### Schritt 18 – Welt mit Chunky vorgenerieren

Chunks „on the fly" zu erzeugen ist der größte Lag-Verursacher bei Crossplay, weil Java- und Bedrock-Clients unterschiedlich nachladen. Chunky erzeugt das Gelände einmal im Voraus. Ingame als OP:

```
/chunky world world
/chunky center 0 0
/chunky radius 3000
/chunky start
```

`/chunky pause` · `/chunky continue` · `/chunky progress` · `/chunky cancel`. Faustregel: Radius 3000 ≈ 6 × 6 km, reicht für die meisten privaten Server. Am besten laufen lassen, wenn niemand online ist.

> **Nether und End:** Seit Paper 26.1 liegen sie im Weltordner (`world/dimensions/minecraft/the_nether` bzw. `the_end`). Chunky 1.5.3 kann sie dort derzeit nicht auswählen ([Chunky-Issue #480](https://github.com/pop4959/Chunky/issues/480)) — bis das behoben ist, nur die Oberwelt vorgenerieren. Nether und End entstehen wie gewohnt beim Erkunden.

---

## Teil 3 – Automatik

Backup, Auto-Update mit Rollback, Watchdog und OS-Sicherheitsupdates — alles meldet sich per [ntfy](https://ntfy.sh) aufs Handy.

### Schritt 19 – Zentrale Config und ntfy

```bash
cd /opt/minecraft-server-guide
cp config/minecraft-crossplay.conf.example /etc/minecraft-guide.conf
nano /etc/minecraft-guide.conf   # NTFY_TOPIC auf einen eigenen, zufälligen Namen setzen!
chmod 600 /etc/minecraft-guide.conf
```

ntfy-App (iOS/Android) installieren und dein `NTFY_TOPIC` abonnieren. Warum der Name zufällig sein muss: [ntfy absichern](#ntfy-absichern).

### Schritt 20 – Scripts installieren

```bash
cd /opt/minecraft-server-guide
install -m 750 scripts/common/mc-common.sh      /usr/local/bin/mc-common.sh
install -m 750 scripts/crossplay/mc-backup.sh   /usr/local/bin/mc-crossplay-backup.sh
install -m 750 scripts/crossplay/mc-update.sh   /usr/local/bin/mc-crossplay-update.sh
install -m 750 scripts/crossplay/mc-watchdog.sh /usr/local/bin/mc-crossplay-watchdog.sh
install -m 750 scripts/os/mc-os-update.sh       /usr/local/bin/mc-os-update.sh
cp config/logrotate-minecraft-guide /etc/logrotate.d/minecraft-guide
```

### Schritt 21 – OS-Sicherheitsupdates einrichten

```bash
apt install -y unattended-upgrades
systemctl disable --now apt-daily-upgrade.timer   # das Anwenden steuert mc-os-update.sh per Cron, fuer saubere ntfy-Meldungen
```

Sicherheitsupdates sind auf beiden Distros ab Werk freigegeben. Prüfen: [Sicherheitsupdates prüfen](#sicherheitsupdates-prüfen).

### Schritt 22 – Testen

```bash
/usr/local/bin/mc-crossplay-backup.sh && ls -lh /home/minecraft/backups/
/usr/local/bin/mc-crossplay-update.sh
/usr/local/bin/mc-crossplay-watchdog.sh; echo "Exit: $?"   # sollte still sein
/usr/local/bin/mc-os-update.sh
```

### Schritt 23 – Cronjobs

```bash
crontab -e
```

```cron
# Watchdog alle 5 Minuten
*/5 * * * * /usr/local/bin/mc-crossplay-watchdog.sh >> /var/log/mc-watchdog.log 2>&1

# Backup um 03:30
30 3 * * * /usr/local/bin/mc-crossplay-backup.sh >> /var/log/mc-backup.log 2>&1

# OS-Sicherheitsupdates um 04:00
0 4 * * * /usr/local/bin/mc-os-update.sh >> /var/log/mc-os-update.log 2>&1

# Paper-Builds, Geyser und Floodgate um 05:00 (Neustart nur, wenn wirklich etwas neu ist)
0 5 * * * /usr/local/bin/mc-crossplay-update.sh >> /var/log/mc-update.log 2>&1
```

### Was automatisch läuft und was nicht

| Aufgabe | Automatisch? | Details |
|---|---|---|
| Watchdog | ✅ alle 5 Minuten | Startet einen abgestürzten Server neu, wartet bis Paper wirklich bereit ist, meldet nur Zustandswechsel |
| Backup | ✅ täglich 03:30 | Welt samt Nether und End, Paper- und Plugin-Configs, Daten von LuckPerms, GriefPrevention, CoreProtect und Essentials, Floodgate-Schlüssel · aufbewahrt 7 Tage (`BACKUP_KEEP_DAYS` in der Config) |
| OS-Sicherheitsupdates | ✅ täglich 04:00 | Neustart wird nur **gemeldet**, nicht erzwungen |
| Geyser + Floodgate | ✅ täglich 05:00 | Müssen mit Bedrock-Client-Updates Schritt halten |
| Paper-Builds **innerhalb** von 26.1.2 | ✅ täglich 05:00 | Patch-Builds sind sicher · vorher Backup, bei Fehlstart automatischer Rollback |
| Paper-Versionssprung, ViaVersion/ViaBackwards, übrige Plugins | ❌ manuell | Bewusste Entscheidung nötig — siehe [Paper und Plugins von Hand aktualisieren](#paper-und-plugins-von-hand-aktualisieren) |
| Distro-Wechsel, Proxmox-Host | ❌ manuell | siehe [Was die Automatik nicht abdeckt](#was-die-automatik-nicht-abdeckt) |

---

## Teil 4 – Sicherheit und Kinderserver

Drei Stufen, die sich kombinieren lassen: wer überhaupt reinkommt, was ein Spieler darf, und was hilft, wenn doch etwas schiefgeht. Standard dieser Anleitung ist **offen und Survival**; für einen Kinderserver gilt das [Kinderserver-Profil](#kinderserver-profil) weiter unten.

### Stufe 1 – Wer darf rein: Whitelist

Standardmäßig **aus** — jeder mit der Adresse kann beitreten. Sinnvoll, sobald der Server aus dem Internet erreichbar ist:

1. `white-list=true` in `server.properties`, Server neu starten
2. Java-Spieler ingame als OP eintragen: `/whitelist add Name`
3. Bedrock-Spieler: `/fwhitelist add Gamertag` — das ist der Floodgate-Befehl, der normale kennt keine Bedrock-Konten

### Stufe 2 – Was darf man: Gamemode und Freischaltung

| Gamemode | Bauen/abbauen? | Items benutzen/aufheben? | Fliegen/durch Wände? |
|---|---|---|---|
| `survival` | ja | ja | nein |
| `creative` | ja, unbegrenzt | ja | ja |
| `adventure` | **nein** | ja (Kisten, Türen, Hebel) | nein |
| `spectator` | **nein** | **nein, gar keine Interaktion** | ja, durch Wände |

**Adventure oder Spectator?** Beide verhindern Bauen und Abbauen. In **Adventure** bewegt man sich normal und kann Dinge benutzen — das fühlt sich für Kinder wie „richtig spielen" an. In **Spectator** fliegt man geisterhaft durch die Welt und kann nichts anfassen — die strengste Stufe, eher zum Zuschauen. Für die meisten Fälle ist **Adventure** der bessere Standard.

**Das Prinzip „kontrolliertes Bauen":** `gamemode=adventure` als Standard, `force-gamemode=false`, und wer bauen darf, wird **einzeln** freigeschaltet — ingame als OP:

- Freischalten: `/gamemode creative Name` (Bedrock-Spieler ohne Kontoverknüpfung: `.Gamertag`)
- Zurücknehmen: `/gamemode adventure Name`

> **Warum `force-gamemode=false` entscheidend ist:** Dann **bleibt** ein freigeschalteter Spieler in seinem Modus, auch nach dem nächsten Login oder einem Neustart. Mit `true` wird jeder bei jedem Login auf den Standard zurückgesetzt — die Freischaltung wäre jedes Mal weg.

### Stufe 3 – Wenn doch etwas passiert: Claims und CoreProtect

Wichtig, sobald Spieler bauen dürfen:

- **GriefPrevention:** Spieler schützen ihr Grundstück mit der goldenen Schaufel selbst (`/trust`, `/untrust`, `/abandonclaim`). Kindgerecht erklärt in der [Spieler-Anleitung](spieler-anleitung.md).
- **Admin-Claim für den Spawn:** als OP `/adminclaims` → mit der goldenen Schaufel zwei Ecken um den Spawn anklicken → `/basicclaims`. Der Spawn ist damit dauerhaft geschützt, gehört keinem Spieler und läuft nie ab. Details: [GriefPrevention](#griefprevention--claims).
- **CoreProtect** als Netz: Geht trotzdem etwas kaputt (Claim vergessen, Missverständnis), macht `/co rollback u:Name t:1h r:20` den Schaden gezielt rückgängig — der Rest der Welt bleibt, wie er ist.
- **Tägliches Backup** aus Teil 3 als letzte Sicherheitsleine: [Backup zurückspielen](#backup-zurückspielen).

### Drei typische Konfigurationen

| Ziel | Stufe 1 | Stufe 2 | Stufe 3 |
|---|---|---|---|
| **Standard** (Survival, offen) | aus | `survival` für alle | optional |
| **Privater Freundeskreis** | Whitelist an | `survival` oder `creative` für die gelisteten Spieler | GriefPrevention empfehlenswert |
| **Kinderserver** | optional | `adventure` als Standard + Freischaltung durch OP | GriefPrevention + Admin-Claim am Spawn + CoreProtect |

### Kinderserver-Profil

Peaceful, niemand baut ohne Freischaltung, eigenes Grundstück per goldener Schaufel, geschützter Spawn und CoreProtect als Netz.

**server.properties** ([Schritt 11](#schritt-11--serverproperties-konfigurieren)):

| Einstellung | Wert | Warum |
|---|---|---|
| `gamemode` | `adventure` | Niemand kann bauen oder abbauen, bevor du es erlaubst |
| `difficulty` | `peaceful` | Keine Monster, kein Hunger |
| `force-gamemode` | `false` | Freigeschaltete Kinder **bleiben** in ihrem Modus |
| `online-mode` | `true` | Anmeldung über Microsoft-Konto — nicht abschalten |
| `enforce-secure-profile` | `false` | Sonst werden Bedrock-Spieler beim Chatten gekickt |

**Freischaltung:** Ein Kind darf bauen → `/gamemode creative NameDesKindes`. Zurück auf „nur anschauen" → `/gamemode adventure NameDesKindes`. Lieber echtes Überleben statt Creative: `/gamemode survival NameDesKindes` plus die Gamerule `keep_inventory` (unten), damit ein Tod nicht alle Sachen kostet.

**Schutz:**

1. **Spawn dauerhaft schützen** (einmalig, als OP): `/adminclaims` → mit der goldenen Schaufel zwei Ecken um den Spawn anklicken → `/basicclaims`.
2. **Kinder claimen ihr Grundstück selbst** — genau das steht in der [Spieler-Anleitung](spieler-anleitung.md), die du ihnen gibst.
3. **CoreProtect als Netz:** `/co rollback u:Name t:1h r:20` macht Schäden rückgängig, zusätzlich zu den täglichen Backups.

#### Gamerules

Ingame als OP, einmal pro Welt. Gamerules werden **in der Welt** gespeichert — sie überstehen Neustarts und Updates und sind im Backup enthalten. `difficulty=peaceful` verhindert schon Monster und Hunger; optional zusätzlich:

| Befehl | Wirkung |
|---|---|
| `/gamerule advance_time false` + `/time set day` | Immer Tag |
| `/gamerule advance_weather false` + `/weather clear` | Immer klares Wetter |
| `/gamerule spawn_mobs false` | Keine Tiere und Monster |
| `/gamerule mob_griefing false` | Mobs verändern keine Blöcke |
| `/gamerule pvp false` | Kinder können sich nicht gegenseitig verletzen |
| `/gamerule fall_damage false` · `/gamerule fire_damage false` | Kein Fall- und Feuerschaden |
| `/gamerule tnt_explodes false` | TNT explodiert nicht |
| `/gamerule keep_inventory true` | Items bleiben beim Tod erhalten (nur in Survival relevant) |

Koordinaten brauchen keine Gamerule: Bedrock-Spieler sehen sie über Geyser automatisch (`gameplay.show-coordinates`), Java-Spieler mit F3.

> **Minecraft Java hat die Gamerules mit 1.21.11 umbenannt** (z.B. `doDaylightCycle` → `advance_time`). Alte Anleitungen im Netz nennen oft noch die alten Namen — die funktionieren auf Paper 26.1.2 nicht mehr. Im Zweifel `/gamerule ` tippen, die Tab-Vervollständigung zeigt die gültigen Namen.

#### Starter-Kit

Die Spieler-Anleitung verweist auf `/kit schaufel` für eine neue goldene Schaufel und nennt ein Start-Paket. Beides in `/home/minecraft/paper/plugins/Essentials/kits.yml` definieren:

```yaml
kits:
  schaufel:
    delay: -1              # -1 = beliebig oft nutzbar
    items:
    - golden_shovel 1
  start:
    delay: -1
    items:
    - stone_pickaxe 1
    - stone_axe 1
    - stone_shovel 1
    - stone_sword 1
    - golden_shovel 1
    - red_bed 1
    - crafting_table 1
    - oak_log 8
    - oak_planks 16
    - bread 8
    - apple 4
    - torch 16
```

> Nach dem Speichern `/essentials reload` und `/kit schaufel` testen — das `kits.yml`-Format kann sich je EssentialsX-Version leicht ändern ([EssentialsX-Doku](https://essentialsx.net/wiki/Kits.html)). Startpaket automatisch beim ersten Login: `EssentialsXSpawn` kann ein Kit an `firstspawn` koppeln, oder man vergibt es einmalig per `/kit start Name`.

#### Spieler-Anleitung zum Weitergeben

**[spieler-anleitung.md](spieler-anleitung.md)** erklärt den Kindern goldene Schaufel, Freunde auf das Grundstück lassen, `/home`, `/tpa` und das Start-Paket — kindgerecht mit Emojis. **[spieler-anleitung-discord.md](spieler-anleitung-discord.md)** ist dieselbe Anleitung in Discord-Nachrichten aufgeteilt.

---

## Teil 5 – Plugins und Befehle

Alle Plugins laufen **auf dem Server** — sie funktionieren automatisch für Java- **und** Bedrock-Spieler, niemand muss etwas installieren.

### Überblick und Abhängigkeiten

| Plugin | Zweck | Abhängigkeit |
|---|---|---|
| **LuckPerms** | Rechte- und Gruppenverwaltung | – |
| **Vault** | Schnittstelle zwischen Plugins (Economy, Chat-Präfixe) | – |
| **EssentialsX** (+Spawn +Chat) | Alltagsbefehle: `/home`, `/tpa`, `/warp`, Kits, optional Economy | Economy und Chat-Präfixe brauchen Vault |
| **CoreProtect** | Protokolliert Blockänderungen, macht Schäden rückgängig | – |
| **GriefPrevention** | Grundstücke per goldener Schaufel, Admin-Claims für den Spawn | – |
| **Chunky** | Welt vorgenerieren, weniger Lag beim Erkunden | – |

### Download-Quellen

Die in [Schritt 10](#schritt-10--plugin-stack-installieren) verlinkten Versionen sind für Paper 26.1.2 geprüft (Stand September 2026). Für neuere Versionen immer auf der offiziellen Seite die **zur Paper-Version passende** wählen:

| Plugin | Quelle |
|---|---|
| LuckPerms | [luckperms.net/download](https://luckperms.net/download) (Variante **Bukkit**) |
| Vault | [github.com/MilkBowl/Vault/releases](https://github.com/MilkBowl/Vault/releases) — letztes Release 2020; bei Problemen ist [VaultUnlocked](https://modrinth.com/plugin/vaultunlocked) der gepflegte Nachfolger |
| EssentialsX | [essentialsx.net/downloads.html](https://essentialsx.net/downloads.html) — Module `EssentialsX`, `EssentialsXSpawn`, `EssentialsXChat` |
| CoreProtect | [modrinth.com/plugin/coreprotect](https://modrinth.com/plugin/coreprotect/versions) |
| GriefPrevention | [github.com/TechFortress/GriefPrevention/releases](https://github.com/TechFortress/GriefPrevention/releases) bzw. [Modrinth](https://modrinth.com/plugin/griefprevention) |
| Chunky | [hangar.papermc.io/pop4959/Chunky](https://hangar.papermc.io/pop4959/Chunky) bzw. [modrinth.com/plugin/chunky](https://modrinth.com/plugin/chunky) — Plattform **Paper** |

Downloads immer prüfen: `file ~/paper/plugins/*.jar` muss `Java archive data (JAR)` oder `Zip archive data` zeigen, nicht `ASCII text` oder `HTML` (= Fehlerseite).

> **CoreProtect** legt beim ersten Start eine SQLite-Datenbank in `plugins/CoreProtect/` an. Sie wächst mit der Zeit und ist im Backup enthalten — für einen privaten Server reicht SQLite locker.

### Befehle eingeben

Ingame im Chat mit `/` — Bedrock-Spieler tippen sie genauso. In der Server-Konsole (nur beim Start von Hand, siehe [Schritt 17](#schritt-17--op-rechte-vergeben)) ohne `/`.

### EssentialsX – Alltagsbefehle

| Befehl | Wirkung |
|---|---|
| `/sethome [name]` · `/home [name]` | Zuhause setzen / dorthin teleportieren |
| `/spawn` · `/setspawn` | Zum Spawn / Spawn festlegen |
| `/tpa <Spieler>` · `/tpaccept` · `/tpdeny` | Teleport-Anfrage stellen / annehmen / ablehnen |
| `/tpahere <Spieler>` | Bittet den Spieler, zu dir zu kommen |
| `/back` | Zurück zum letzten Ort (z.B. nach dem Tod) |
| `/warp <name>` · `/setwarp <name>` | Öffentlichen Wegpunkt nutzen / anlegen |
| `/msg <Spieler> <Text>` · `/r` | Private Nachricht / Antwort |
| `/kit [name]` | Item-Set ausgeben (definiert in `kits.yml`) |
| `/heal` · `/feed` · `/god` | Heilen / sättigen / unverwundbar (Admin) |
| `/gms` · `/gmc` · `/gma` · `/gmsp` | Gamemode Survival / Creative / Adventure / Spectator |

### GriefPrevention – Claims

| Befehl | Wirkung |
|---|---|
| Goldene Schaufel, zwei gegenüberliegende Ecken anklicken | Grundstück claimen |
| `/trust <Spieler>` · `/untrust <Spieler>` | Freund auf dem eigenen Grundstück bauen lassen / Recht entziehen |
| `/abandonclaim` | Eigenes Grundstück aufgeben |
| `/claimslist` | Eigene Grundstücke anzeigen |
| `/adminclaims` | **Als OP:** Schaufel in den Admin-Modus schalten — der nächste Claim gehört keinem Spieler und läuft nie ab. **So schützt du den Spawn dauerhaft.** |
| `/basicclaims` | Schaufel zurück in den normalen Modus schalten |
| `/ignoreclaims` | **Als OP:** Claim-Grenzen vorübergehend ignorieren (z.B. um am Spawn zu bauen) |

**Spawn schützen:** einmalig als OP `/adminclaims`, dann mit der goldenen Schaufel zwei Ecken um den Spawn-Bereich anklicken. Danach `/basicclaims` — sonst wird auch der nächste eigene Claim ein Admin-Claim.

### CoreProtect – Protokoll und Rollback

| Befehl | Wirkung |
|---|---|
| `/co inspect` (kurz `/co i`) | Inspektor umschalten, dann Block anklicken → wer hat wann was gemacht |
| `/co rollback u:Name t:1h r:20` | Änderungen eines Spielers der letzten Stunde im Umkreis von 20 Blöcken zurückrollen |
| `/co restore u:Name t:1h r:20` | Gegenteil von rollback, falls zu viel zurückgerollt wurde |

### LuckPerms – Rechte

```
/lp creategroup builder
/lp group builder permission set essentials.kit.schaufel true
/lp user MaxPower3309 parent add builder
/lp editor
```

`/lp editor` erzeugt einen Link, unter dem sich Gruppen und Rechte bequem im Browser bearbeiten lassen. Volle Doku: [luckperms.net/wiki](https://luckperms.net/wiki/Home).

> **Ohne Kontoverknüpfung** ([Schritt 14](#schritt-14--floodgate-kontoverknüpfung)) hängen Rechte am Spielernamen — dann müssen sie an `MaxPower3309` **und** an `.MaxPower3309` (Bedrock) vergeben werden.

### Chunky

Siehe [Schritt 18](#schritt-18--welt-mit-chunky-vorgenerieren).

---

## Teil 6 – Wartung und Troubleshooting

**Faustregel:** Im Alltag musst du nichts tun. Aufmerksam werden solltest du nur, wenn eine **ntfy-Meldung** kommt — die Nachricht sagt jeweils, was zu prüfen ist.

### Server steuern

```bash
systemctl start|stop|restart|status minecraft-paper
journalctl -u minecraft-paper -n 50            # letzte 50 Log-Einträge
journalctl -u minecraft-paper -f --no-pager    # Live-Log, Ctrl+C zum Beenden
```

> Ein nur mit `systemctl stop` angehaltener Server wird vom Watchdog nach spätestens 5 Minuten wieder gestartet. Für kurze Arbeiten das [Wartungs-Flag](#wartungs-flag) setzen, für längere Pausen die Watchdog-Zeile in `crontab -e` auskommentieren.

### Wartungs-Flag

```bash
touch /run/minecraft-paper.maintenance   # Watchdog pausieren
rm /run/minecraft-paper.maintenance      # wieder freigeben
```

Solange das Flag existiert, greift der Watchdog nicht ein. Es gilt maximal 60 Minuten, danach räumt der Watchdog es selbst weg — bei längeren Arbeiten zwischendurch erneut `touch`. Backup und Update setzen das Flag automatisch.

### Automatik von Hand anstoßen

| Befehl | Wirkung |
|---|---|
| `/usr/local/bin/mc-crossplay-backup.sh` | Backup sofort erstellen |
| `/usr/local/bin/mc-crossplay-update.sh` | Update sofort prüfen und ggf. durchführen |
| `/usr/local/bin/mc-crossplay-watchdog.sh` | Überwachung sofort ausführen |
| `/usr/local/bin/mc-os-update.sh` | OS-Sicherheitsupdates sofort ausführen |

### Backup zurückspielen

```bash
touch /run/minecraft-paper.maintenance
systemctl stop minecraft-paper
ls -lh /home/minecraft/backups/     # gewünschtes Backup aussuchen
rm -rf /home/minecraft/paper/world  # nicht mit dem Backup mischen (Weltname = level-name)
tar -xzf /home/minecraft/backups/paper-backup-DATUM.tar.gz -C /home/minecraft/paper
chown -R minecraft:minecraft /home/minecraft/paper
systemctl start minecraft-paper
rm /run/minecraft-paper.maintenance
```

Das setzt Welt, Configs und Plugin-Daten (auch das CoreProtect-Protokoll) auf den Stand des Backups zurück. Wer unsicher ist, sichert vorher noch den aktuellen Stand mit `/usr/local/bin/mc-crossplay-backup.sh`.

### Welt zurücksetzen oder neu würfeln

**Immer zuerst ein Backup:** `/usr/local/bin/mc-crossplay-backup.sh`

**Komplett neue Welt, alte löschen:**

```bash
touch /run/minecraft-paper.maintenance
systemctl stop minecraft-paper
rm -rf /home/minecraft/paper/world   # Weltname = level-name; enthaelt ab Paper 26.1 auch Nether und End
systemctl start minecraft-paper
rm /run/minecraft-paper.maintenance
```

**Neue Welt, alte behalten:** `level-name` in `server.properties` auf einen neuen Namen ändern und neu starten. Die alte Welt bleibt unter ihrem Ordnernamen erhalten und lässt sich durch Zurücksetzen des Namens jederzeit wieder aktivieren.

**Bestimmten Seed statt Zufall:** vor dem Start `level-seed=<Wert>` setzen. Danach die neue Welt wieder mit Chunky vorgenerieren ([Schritt 18](#schritt-18--welt-mit-chunky-vorgenerieren)).

### Paper und Plugins von Hand aktualisieren

**Paper-Versionssprung** (z.B. 26.1.2 → 26.2) — erst, wenn Geyser und alle Plugins so weit sind:

1. Prüfen, ob Geyser **und alle Plugins** (vor allem EssentialsX und CoreProtect) die Zielversion offiziell unterstützen.
2. Plugins bei Bedarf zuerst aktualisieren (siehe unten).
3. `PAPER_MC_VERSION` in `/etc/minecraft-guide.conf` anpassen.
4. `/usr/local/bin/mc-crossplay-update.sh` laufen lassen — holt den neuesten Build der neuen Version, mit Backup und Rollback.

> **Achtung:** Die Welt wird beim ersten Start mit der neuen Version **unumkehrbar** umgewandelt. Ein Rollback der JAR hilft danach nicht mehr — nur das Backup von vor dem Sprung.

**ViaVersion/ViaBackwards:** aktuelle Version auf [hangar.papermc.io/ViaVersion/ViaVersion/versions](https://hangar.papermc.io/ViaVersion/ViaVersion/versions) nachsehen, die Links aus [Schritt 9](#schritt-9--geyser-floodgate-viaversion-und-viabackwards) mit der neuen Versionsnummer ausführen, Server neu starten.

**LuckPerms, EssentialsX, CoreProtect, GriefPrevention, Chunky:** neue JAR von der [Download-Quelle](#download-quellen) unter demselben Dateinamen wie in [Schritt 10](#schritt-10--plugin-stack-installieren) nach `/home/minecraft/paper/plugins/` laden, `chown minecraft:minecraft` darauf, Server neu starten. Vorher ein Backup.

### Sicherheitsupdates prüfen

Beide Distros geben Sicherheitsupdates für `unattended-upgrades` ab Werk frei. Kontrolle:

```bash
unattended-upgrade --dry-run -d 2>&1 | grep -i 'allowed origins'
```

Die Zeile muss `-security` (Ubuntu) bzw. `Debian-Security` (Debian) enthalten. Was nachts installiert wurde, steht in `/var/log/mc-os-update.log`.

### Was die Automatik nicht abdeckt

| Aufgabe | Wie oft | Was tun |
|---|---|---|
| **Paper-Versionssprung, ViaVersion, übrige Plugins** | gelegentlich | siehe [Paper und Plugins von Hand aktualisieren](#paper-und-plugins-von-hand-aktualisieren) |
| **Distro-Wechsel** (Ubuntu 24.04 → 26.04, Debian 13 → 14) | alle paar Jahre | Bewusst und mit Proxmox-Snapshot vorher (`pct snapshot <CTID> vor-upgrade`); bei Ubuntu über `do-release-upgrade`, bei Debian über die Paketquellen auf den neuen Codenamen. |
| **Support-Ende der Distro** | nach ca. 5 Jahren | Ubuntu: **Ubuntu Pro** ist für Privatnutzung kostenlos und verlängert die Sicherheitsupdates um Jahre. Debian: Die LTS-Phase läuft automatisch über die normalen Paketquellen; danach gibt es nur noch kostenpflichtiges ELTS — rechtzeitig auf die nächste Version wechseln. |
| **Proxmox-Host-Updates** | gelegentlich | Laufen auf dem Host, nicht im LXC. |
| **Kernel** | – | Kommt vom Host — im LXC nichts zu tun. |

### ntfy-Meldungen

| Titel | Bedeutung | Handlungsbedarf |
|---|---|---|
| `Crossplay: Update erfolgreich` | Aktualisiert und sauber gestartet. | Nein |
| `Crossplay: Paper-Check fehlgeschlagen` | Paper-API nicht erreichbar; Geyser und Floodgate wurden trotzdem geprüft. | Nur wenn es sich wiederholt |
| `Crossplay: Update abgebrochen` | Backup vor dem Update fehlgeschlagen, nichts geändert. | `ls -lh /home/minecraft/backups` und `df -h` prüfen |
| `Crossplay: Update fehlgeschlagen (Rollback)` | Neue Version startete nicht, alte JARs laufen wieder. | Bei Gelegenheit Logs ansehen |
| `Crossplay: KRITISCH - Server unten` | Update **und** Rollback gescheitert. | **Ja, sofort** — Befehle stehen in der Nachricht |
| `Crossplay: Backup-Problem` | Das Backup wurde evtl. nicht sauber erstellt. | `ls -lh /home/minecraft/backups` und `df -h` prüfen |
| `Crossplay: automatisch neu gestartet` | Watchdog hat den Server wieder hochgefahren. | Nein, im Auge behalten falls häufig |
| `Crossplay: Server DOWN` | Server weg, automatischer Neustart hat nicht geholfen. | **Ja** — Befehle stehen in der Nachricht |
| `Crossplay: wieder online` | Nach einem Ausfall wieder erreichbar. | Nein |
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
| Geyser stürzt mit `ExceptionInInitializerError` ab | Paper-Version zu neu für Geyser — auf der gepinnten Version bleiben, bis Geyser nachzieht |
| Bedrock-Spieler kommen nicht rein, Java-Spieler schon | **UDP** 19132 in `ufw` und im Router prüfen; im Log muss `Started Geyser on UDP port 19132` stehen |
| Bedrock-Spieler werden beim Chatten gekickt | `enforce-secure-profile=false` in `server.properties` prüfen |
| `/linkaccount` ist unbekannt | `enable-own-linking: true` und `floodgate-sqlite-database.jar` in `plugins/floodgate/` ([Schritt 14](#schritt-14--floodgate-kontoverknüpfung)) |
| Gamerule ist unbekannt | Seit 1.21.11 gelten neue Namen — `/gamerule ` tippen, Tab-Vervollständigung zeigt sie |
| Plugin lädt nicht | `file datei.jar` zeigt `HTML`/`ASCII text` statt `Java archive data`/`Zip archive data` → war eine Fehlerseite, Link neu kopieren; sonst prüfen, ob das Plugin die Paper-Version unterstützt |
| Von außen kommt niemand rein | Port-Forwarding und feste IP prüfen; CGNAT siehe [Weitere Empfehlungen](#weitere-empfehlungen) |
| `apt`-Befehl meldet „could not get lock" | Gerade läuft ein anderer apt-Vorgang (z.B. `mc-os-update.sh` oder der tägliche Paketlisten-Abgleich) — kurz warten und erneut versuchen |
| `journalctl`-Zeile endet mit `>` | Nur abgeschnitten (Pager) — `q` zum Verlassen, oder `--no-pager` anhängen |

---

## Teil 7 – Erweiterungen

Bewusst nicht Teil des Standard-Setups, damit der Server nicht überfrachtet startet — Ideen für später, jeweils mit dem einfachsten sinnvollen Einstieg.

> **Grundsatz:** lieber ein Plugin zu wenig als zu viel. Jedes zusätzliche Plugin ist eine weitere Abhängigkeit beim nächsten [Paper-Versionssprung](#paper-und-plugins-von-hand-aktualisieren).

### Einfaches Economy-System

Der einfachste Einstieg nutzt, was schon installiert ist: **EssentialsX-Economy über Vault** — kein zusätzliches Plugin nötig.

1. In `plugins/Essentials/config.yml` ein Startguthaben setzen (`starting-balance:`).
2. Spieler haben automatisch `/balance` und `/pay <Spieler> <Betrag>`.
3. Als Admin Guthaben vergeben: `/eco give <Spieler> <Betrag>` (z.B. als Belohnung).

Reicht das nicht mehr (echte Shops, Spieler verkaufen sich gegenseitig Items)? Dann ein Shop-Plugin wie **ChestShop** (Spieler richten eigene Verkaufskisten ein) oder **ShopGUIPlus** (Menü-Shop, kostenpflichtig) — beide bauen auf Vault auf und nutzen dieselbe Economy.

### WorldEdit und WorldGuard

GriefPrevention schützt die Grundstücke der Spieler. Sollen in einer Region eigene Regeln gelten (z.B. PvP an/aus unabhängig von Claims) oder braucht ihr Terrain-Werkzeuge (Bereiche kopieren, füllen, Schematics):

- **WorldEdit** zuerst installieren — Terrain-Werkzeug: `//wand`, `//set`, `//copy`, `//paste`.
- **WorldGuard** danach (braucht WorldEdit): eigene Regionen mit Regeln, z.B. `/rg define spawn`, dann Flags wie `pvp deny`.
- Beide laufen problemlos **parallel** zu GriefPrevention: WorldGuard für Bereiche, die der Admin festlegt, GriefPrevention für die Grundstücke der Spieler.

Download: [WorldEdit auf Hangar](https://hangar.papermc.io/EngineHub/WorldEdit/versions), [WorldGuard auf Modrinth](https://modrinth.com/plugin/worldguard/versions). Vorher prüfen, dass beide Paper 26.1.2 unterstützen.

### Discord-Anbindung

**DiscordSRV** verbindet den Minecraft-Chat mit einem Discord-Channel (in beide Richtungen) und meldet, wer kommt und geht. Passt gut zur [Discord-Version der Spieler-Anleitung](spieler-anleitung-discord.md). Einrichtung: Bot im Discord-Developer-Portal anlegen, Token in `plugins/DiscordSRV/config.yml` eintragen.

### Mehrere Welten

**Multiverse-Core** erlaubt mehrere Welten auf demselben Server — z.B. eine Survival- und eine separate Creative-Bauwelt, oder eine eigene Welt pro Kind. `/mv create <name> normal` legt eine Welt an, `/mv tp <name>` wechselt hinein. Chunky ([Schritt 18](#schritt-18--welt-mit-chunky-vorgenerieren)) lässt sich pro Welt einzeln anwenden.

### Weitere Plugins bei Bedarf

- **TAB** — Tabliste und Namensschilder gestalten (rein kosmetisch).
- **Prism** — Alternative oder Ergänzung zu CoreProtect, falls dessen Rollback-Möglichkeiten einmal nicht reichen.

---

## Weitere Empfehlungen

1. **DDNS für Freunde von außerhalb** (DuckDNS, FRITZ!Box MyFRITZ!), falls sich die öffentliche IP ändert.
2. **CGNAT/DS-Lite prüfen**, falls Port-Forwarding gar nicht ankommt: öffentliche IP mit der WAN-IP des Routers vergleichen; `100.64.x.x` = CGNAT. Lösung: echte IPv4 beim Provider anfragen, IPv6 nutzen, oder Tailscale/ZeroTier.
3. **Proxmox-Snapshot als zweite Sicherheitsleine** vor größeren Eingriffen: `pct snapshot <CTID> vor-update`, im Notfall `pct rollback <CTID> vor-update`. Zusätzlich einen wöchentlichen `vzdump` einrichten.
4. **Off-Site-Backup:** Die Backups liegen sonst nur im selben LXC. Per `rsync`/`rclone` nachts aufs NAS oder in die Cloud kopieren.
5. **RAM und CPU sparen:** `view-distance` und `simulation-distance` in `server.properties` reduzieren (z.B. 8 und 6) und `-Xmx` im Service zum LXC passend setzen.
6. **Konsolen-Clients (Xbox/PlayStation/Switch)** können keine eigene Server-Adresse eintragen — nur Handy, Tablet und Windows. Vorher einplanen, falls die Familie auf Konsole spielt.

# Crossplay-Server: Java + Bedrock + Plugins (Debian/Ubuntu, Proxmox LXC)

PaperMC 26.1.2 + Geyser + Floodgate + ViaVersion/ViaBackwards + LuckPerms · Vault · EssentialsX · CoreProtect · GriefPrevention · Chunky.

Voraussetzungen zuerst: **[docs/00-voraussetzungen.md](../00-voraussetzungen.md)** (Sizing, Repo klonen, Java 25, Benutzer `minecraft`).

> **Die wichtigste Regel dieses Wegs: Geyser und die Plugins sind der limitierende Faktor.** Wir nutzen Paper **26.1.2**, nicht die neueste Version 26.2 — es ist die höchste Version, die Geyser **und** alle Plugins offiziell unterstützen (EssentialsX und CoreProtect haben für 26.2 noch kein Release). Reihenfolge bei jedem größeren Sprung: **erst prüfen, ob Geyser und alle Plugins die Zielversion können, dann Paper.** Java-Clients mit neueren Versionen können sich trotzdem verbinden — dafür installieren wir ViaVersion + ViaBackwards.

## Schritt 1 – PaperMC herunterladen

```bash
mkdir -p /home/minecraft/paper && cd /home/minecraft/paper
wget -O paper.jar \
  "https://fill-data.papermc.io/v1/objects/1d70b1dab9cf4a6de615209a536f3a45a2186240253c428213ce2188ab95e5f7/paper-26.1.2-74.jar"
chown -R minecraft:minecraft /home/minecraft/paper
```

Datei sollte 50–60 MB sein. Aktueller Link falls dieser abläuft: [papermc.io/downloads/paper](https://papermc.io/downloads/paper) → Version **26.1.2** wählen → Download-Link kopieren.

## Schritt 2 – EULA & Teststart

```bash
su - minecraft
cd ~/paper
java -Xms2G -Xmx4G -jar paper.jar --nogui
```

Stoppt beim ersten Start mit EULA-Hinweis. `nano eula.txt` → `eula=true`, speichern, erneut starten. Bei `Done (...)` in der Konsole `stop` eingeben.

## Schritt 3 – Geyser, Floodgate, ViaVersion/ViaBackwards

Noch als `minecraft`-User:

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

> Beide Via-Plugins **immer aus demselben Channel** (Release) und **derselben Version** ziehen, nie mischen.

## Schritt 4 – Plugin-Stack installieren

Noch als `minecraft`-User im `plugins`-Ordner. Reihenfolge/Abhängigkeiten und Download-Quellen: **[plugins-und-befehle.md](plugins-und-befehle.md)**.

```bash
# LuckPerms, Vault, EssentialsX (+Spawn +Chat), CoreProtect, GriefPrevention, Chunky
# Feste Links mit Versionsnummer, alle fuer Paper 26.1.2 geprueft (Stand September 2026).
# Neuere Versionen: Quellen in plugins-und-befehle.md
wget -O LuckPerms.jar        "https://cdn.modrinth.com/data/Vebnzrzj/versions/b0mk8uS6/LuckPerms-Bukkit-5.5.71.jar"
wget -O Vault.jar            "https://github.com/MilkBowl/Vault/releases/download/1.7.3/Vault.jar"
wget -O CoreProtect.jar      "https://cdn.modrinth.com/data/Lu3KuzdV/versions/Kma0kBsY/CoreProtect-CE-24.0.jar"
wget -O GriefPrevention.jar  "https://cdn.modrinth.com/data/O4o4mKaq/versions/dGfCZHqk/GriefPrevention.jar"
wget -O Chunky.jar           "https://cdn.modrinth.com/data/fALzjamp/versions/MdY6JATr/Chunky-Bukkit-1.5.3.jar"
wget -O EssentialsX.jar      "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsX-2.22.0.jar"
wget -O EssentialsXSpawn.jar "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsXSpawn-2.22.0.jar"
wget -O EssentialsXChat.jar  "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsXChat-2.22.0.jar"

ls -lh ~/paper/plugins && file ~/paper/plugins/*.jar
```

**Jede** Datei muss als `Java archive data (JAR)` oder `Zip archive data` erkannt werden (eine JAR ist ein ZIP). Steht dort `HTML document` oder `ASCII text`, war der Download eine Fehlerseite. Die Größe sagt wenig: EssentialsXSpawn hat nur rund 20 KB, EssentialsX knapp 5 MB.

> WorldEdit/WorldGuard sind **bewusst nicht** im Standard-Stack — GriefPrevention allein deckt Claims (inkl. Spawn-Schutz) ab, siehe [Sicherheits-Stufen](../03-sicherheit-und-kinder/). WorldGuard/WorldEdit als Ausbaustufe: [docs/05-erweiterungen](../05-erweiterungen/).

## Schritt 5 – server.properties

```bash
exit   # zurueck zu root
nano /home/minecraft/paper/server.properties
```

| Einstellung | Standard (vanilla survival) | Kinderserver-Variante |
|---|---|---|
| `gamemode` | `survival` | `adventure` |
| `difficulty` | `easy`/`normal` | `peaceful` |
| `online-mode` | `true` — **nicht ändern!** | `true` |
| `enforce-secure-profile` | **`false`** — sonst werden Bedrock-Spieler beim Chatten gekickt (siehe Info unten) | `false` |
| `max-players` | nach Bedarf | nach Bedarf |

> **`enforce-secure-profile=false` ist bei Crossplay Pflicht, nicht optional.** Diese Einstellung verlangt von Java-Clients kryptografisch signierte Chat-Nachrichten von Mojangs Java-Auth-Servern. Bedrock-Clients (über Floodgate) werden über Microsoft/Xbox authentifiziert, nicht über Mojangs Java-Auth — sie können das technisch nicht liefern und würden beim ersten Chatversuch rausgeworfen. `false` ist die offizielle Floodgate-Empfehlung für private Crossplay-Server.

Gamemode/Difficulty-Details, `force-gamemode`-Verhalten und das komplette Kinderserver-Profil: **[docs/03-sicherheit-und-kinder](../03-sicherheit-und-kinder/)**.

## Schritt 6 – Einmal starten, damit alle Plugins ihre Configs erzeugen

```bash
su - minecraft
cd ~/paper
java -Xms2G -Xmx4G -jar paper.jar --nogui
```

Log sollte u.a. zeigen: `[LuckPerms] Successfully enabled`, `[CoreProtect] Enabled`, `[GriefPrevention] ... enabled`, `[Essentials] Enabled`, `[floodgate] ... Floodgate`, `[Geyser-Spigot] Started Geyser on UDP port 19132`, `[ViaVersion] Loading ViaVersion`. Dann `stop`, `exit`.

> Stürzt Geyser mit `ExceptionInInitializerError` ab: Paper-Version ist zu neu für Geyser — auf der gepinnten Version bleiben, bis Geyser nachzieht.

## Schritt 7 – Geyser konfigurieren

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

> Drei MOTD-Felder beschreiben denselben Server: `motd=` in `server.properties` (Java-Liste), `motd.primary-motd` (Bedrock-Liste), `gameplay.server-name` (Bedrock ingame) — überall denselben Namen setzen.

## Schritt 8 – Floodgate Account-Linking (optional, empfohlen)

Damit Java- und Bedrock-Client dieselbe Identität (Rechte, Claims, Inventar) teilen. Für die Verknüpfung auf dem eigenen Server braucht Floodgate eine Datenbank-Erweiterung — sie kommt in den Floodgate-Ordner:

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

Verlinkung im Spiel: mit dem Java-Client einloggen → im Java-Chat `/linkaccount BedrockName` (zeigt einen Code) → mit dem Bedrock-Client einloggen (erscheint als `.BedrockName`) → im Bedrock-Chat `/linkaccount JavaName Code`. Der Bedrock-Client wird danach einmal gekickt, beim nächsten Login sind beide Konten verknüpft. Ohne Linking sind Java- und Bedrock-Account **zwei verschiedene Spieler** — Rechte, Claims und Homes müssten doppelt vergeben werden.

## Schritt 9 – systemd, Firewall, Port-Forwarding

```bash
cd /opt/minecraft-server-guide
cp systemd/minecraft-paper.service /etc/systemd/system/minecraft-paper.service
nano /etc/systemd/system/minecraft-paper.service   # -Xmx an dein LXC-RAM anpassen
systemctl daemon-reload
systemctl enable --now minecraft-paper
journalctl -u minecraft-paper -n 50
```

```bash
ufw allow 22/tcp
ufw allow 25565/tcp    # Java
ufw allow 19132/udp    # Bedrock via Geyser
ufw enable
```

Router: TCP 25565→25565 und UDP 19132→19132, beide auf die (feste!) LXC-IP.

## Schritt 10 – Welt mit Chunky vorgenerieren (Standard)

Chunk-Generierung „on the fly" ist der größte Lag-Verursacher bei Crossplay (Java/Bedrock laden unterschiedlich nach). Chunky generiert das Gelände einmal im Voraus.

Ingame als OP (siehe [docs/06-wartung](../06-wartung/) für OP vergeben):

```
/chunky world world
/chunky center 0 0
/chunky radius 3000
/chunky start
```

`/chunky pause` / `/chunky continue` / `/chunky progress` / `/chunky cancel`. Faustregel: Radius 3000 ≈ 6×6 km, reicht für die meisten privaten Server. Am besten laufen lassen, wenn niemand online ist.

> **Nether und End:** Seit Paper 26.1 liegen sie im Weltordner (`world/dimensions/minecraft/the_nether` bzw. `the_end`). Chunky 1.5.3 kann sie dort derzeit nicht auswählen ([Chunky-Issue #480](https://github.com/pop4959/Chunky/issues/480)) — bis das behoben ist, nur die Oberwelt vorgenerieren. Nether und End entstehen wie gewohnt beim Erkunden.

## Schritt 11 – ntfy, zentrale Config, Backup/Update/Watchdog, OS-Updates

```bash
cd /opt/minecraft-server-guide
cp config/minecraft-crossplay.conf.example /etc/minecraft-guide.conf
nano /etc/minecraft-guide.conf   # NTFY_TOPIC auf einen eigenen, zufälligen Namen setzen!
chmod 600 /etc/minecraft-guide.conf

install -m 750 scripts/common/mc-common.sh     /usr/local/bin/mc-common.sh
install -m 750 scripts/crossplay/mc-backup.sh   /usr/local/bin/mc-crossplay-backup.sh
install -m 750 scripts/crossplay/mc-update.sh   /usr/local/bin/mc-crossplay-update.sh
install -m 750 scripts/crossplay/mc-watchdog.sh /usr/local/bin/mc-crossplay-watchdog.sh
install -m 750 scripts/os/mc-os-update.sh       /usr/local/bin/mc-os-update.sh
cp config/logrotate-minecraft-guide /etc/logrotate.d/minecraft-guide
```

### OS-Sicherheitsupdates einrichten (einmalig, beide Distros)

```bash
apt install -y unattended-upgrades
systemctl disable --now apt-daily-upgrade.timer   # das Anwenden steuert mc-os-update.sh per Cron, fuer saubere ntfy-Meldungen
```

> Sicherheitsupdates sind auf beiden Distros ab Werk freigegeben. Prüfbefehl: [docs/06-wartung](../06-wartung/#sicherheitsupdates-prüfen).

### Testen

```bash
/usr/local/bin/mc-crossplay-backup.sh && ls -lh /home/minecraft/backups/
/usr/local/bin/mc-crossplay-update.sh
/usr/local/bin/mc-crossplay-watchdog.sh; echo "Exit: $?"   # sollte still sein
/usr/local/bin/mc-os-update.sh
```

### Cronjobs

```bash
crontab -e
```

```cron
# Taegliches Welt-Backup um 03:30
30 3 * * * /usr/local/bin/mc-crossplay-backup.sh >> /var/log/mc-backup.log 2>&1

# OS-Sicherheitsupdates um 04:00
0 4 * * * /usr/local/bin/mc-os-update.sh >> /var/log/mc-os-update.log 2>&1

# Geyser/Floodgate/Paper-Build-Update um 05:00 (Neustart nur wenn wirklich was neu ist)
0 5 * * * /usr/local/bin/mc-crossplay-update.sh >> /var/log/mc-update.log 2>&1

# Watchdog alle 5 Minuten
*/5 * * * * /usr/local/bin/mc-crossplay-watchdog.sh >> /var/log/mc-watchdog.log 2>&1
```

### Was automatisch läuft und was nicht

| Komponente | Automatisch? | Warum |
|---|---|---|
| OS-Sicherheitsupdates | ✅ täglich | Sicherheit. Neustart wird nur **gemeldet**, nicht erzwungen. |
| Geyser + Floodgate | ✅ täglich | Müssen mit Bedrock-Client-Updates Schritt halten, haben stabile `latest`-URLs. |
| Paper, nur Builds **innerhalb** der gepinnten Version | ✅ täglich | Patch-Builds sind sicher. Major-Sprünge **nicht** — das ist der Geyser-Flaschenhals. |
| Paper Major-Version, ViaVersion/ViaBackwards, alle übrigen Plugins | ❌ manuell | Bewusste Entscheidung nötig (Geyser-Kompatibilität prüfen) bzw. unzuverlässige Download-Quelle. Ablauf: [docs/06-wartung](../06-wartung/). |

Weiter: **[Plugin-Referenz & Befehle](plugins-und-befehle.md)** · **[Sicherheits-Stufen & Kinderserver-Profil](../03-sicherheit-und-kinder/)** · **[Erweiterungen](../05-erweiterungen/)** · **[Wartung](../06-wartung/)**

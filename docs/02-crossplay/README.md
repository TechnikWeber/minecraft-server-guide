# Crossplay-Server: Java + Bedrock + Plugins (Debian/Ubuntu, Proxmox LXC)

PaperMC 1.21.11 + Geyser + Floodgate + ViaVersion/ViaBackwards + LuckPerms · Vault · EssentialsX · CoreProtect · GriefPrevention · Chunky.

Voraussetzungen zuerst: **[docs/00-voraussetzungen.md](../00-voraussetzungen.md)** (Sizing, Repo klonen, Java 25, Benutzer `minecraft`).

> **Die wichtigste Regel dieses Wegs: Geyser ist immer der limitierende Faktor.** Wir nutzen Paper **1.21.11**, nicht die neueste Version — Geyser muss eine Paper-Version erst unterstützen, bevor wir hochziehen. Reihenfolge bei jedem größeren Sprung: **erst prüfen, ob Geyser die Zielversion kann, dann Paper.** Java-Clients mit neueren Versionen können sich trotzdem verbinden — dafür installieren wir ViaVersion + ViaBackwards.

## Schritt 1 – PaperMC herunterladen

```bash
mkdir -p /home/minecraft/paper && cd /home/minecraft/paper
wget -O paper.jar \
  "https://fill-data.papermc.io/v1/objects/25eb85bd8415195ce4bc188e1939e0c7cef77fb51d26d4e766407ee922561097/paper-1.21.11-130.jar"
chown -R minecraft:minecraft /home/minecraft/paper
```

Datei sollte 50–60 MB sein. Aktueller Link falls dieser abläuft: [papermc.io/downloads/paper](https://papermc.io/downloads/paper) → Version **1.21.11** wählen → Download-Link kopieren.

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

ls -lh *.jar && file *.jar   # jede Datei muss "Java archive data (JAR)" sein
```

> Beide Via-Plugins **immer aus demselben Channel** (Release) und **derselben Version** ziehen, nie mischen.

## Schritt 4 – Plugin-Stack installieren

Noch als `minecraft`-User im `plugins`-Ordner. Reihenfolge/Abhängigkeiten und Download-Quellen: **[plugins-und-befehle.md](plugins-und-befehle.md)**.

```bash
# LuckPerms, Vault, EssentialsX (+Spawn +Chat), CoreProtect, GriefPrevention, Chunky
# Aktuelle Download-Links jeweils von der offiziellen Quelle holen (siehe plugins-und-befehle.md):
wget -O LuckPerms.jar        "LINK_LUCKPERMS_BUKKIT_HIER"
wget -O Vault.jar             "LINK_VAULT_RELEASE_HIER"
wget -O CoreProtect.jar       "LINK_COREPROTECT_1.21.11_HIER"
wget -O GriefPrevention.jar   "LINK_GRIEFPREVENTION_RELEASE_HIER"
wget -O Chunky.jar            "LINK_CHUNKY_PAPER_HIER"
wget -O EssentialsX.jar       "LINK_ESSENTIALSX_HIER"
wget -O EssentialsXSpawn.jar  "LINK_ESSENTIALSX_SPAWN_HIER"
wget -O EssentialsXChat.jar   "LINK_ESSENTIALSX_CHAT_HIER"

ls -lh ~/paper/plugins && file ~/paper/plugins/*.jar
```

**Jede** Datei muss mehrere MB groß sein und als `Java archive data (JAR)` erkannt werden — sonst war der Download eine Fehlerseite.

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
su - minecraft && cd ~/paper
java -Xms2G -Xmx4G -jar paper.jar --nogui
```

Log sollte u.a. zeigen: `[LuckPerms] Successfully enabled`, `[CoreProtect] Enabled`, `[GriefPrevention] ... enabled`, `[Essentials] Enabled`, `[floodgate] ... Floodgate`, `[Geyser-Spigot] Started Geyser on UDP port 19132`, `[ViaVersion] Loading ViaVersion`. Dann `stop`, `exit`.

> Stürzt Geyser mit `ExceptionInInitializerError` ab: Paper-Version ist zu neu für Geyser — auf 1.21.11 bleiben, bis Geyser nachzieht.

## Schritt 7 – Geyser konfigurieren

```bash
nano /home/minecraft/paper/plugins/Geyser-Spigot/config.yml
```

```yaml
bedrock:
  motd:
    primary-motd: DeinServerName
gameplay:
  server-name: DeinServerName
java:
  auth-type: floodgate   # <- der wichtigste Punkt
```

> Drei MOTD-Felder beschreiben denselben Server: `motd=` in `server.properties` (Java-Liste), `bedrock.motd.primary-motd` (Bedrock-Liste), `gameplay.server-name` (Bedrock ingame) — überall denselben Namen setzen.

## Schritt 8 – Floodgate Account-Linking (optional, empfohlen)

Damit Java- und Bedrock-Client dieselbe Identität (Rechte, Claims, Inventar) teilen:

```bash
nano /home/minecraft/paper/plugins/floodgate/config.yml
```

```yaml
player-link:
  enabled: true
  require-link: false
  allowed: true
```

Verlinkung im Spiel: Java-Client einloggen → im Java-Chat `/linkaccount` (zeigt Code) → mit Bedrock-Client einloggen (erst als `.Name`) → im Bedrock-Chat `/linkaccount JavaName <code>`. Ohne Linking sind Java- und Bedrock-Account **zwei verschiedene Spieler** — Rechte, Claims und Homes müssten doppelt vergeben werden.

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

`/chunky pause` / `/chunky continue` / `/chunky progress` / `/chunky cancel`. Faustregel: Radius 3000 ≈ 6×6 km, reicht für die meisten privaten Server. Am besten laufen lassen, wenn niemand online ist. Nether ggf. separat mit kleinerem Radius (8× komprimiert):

```
/chunky world world_nether
/chunky radius 1000
/chunky start
```

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
```

Testen:

```bash
/usr/local/bin/mc-crossplay-backup.sh && ls -lh /home/minecraft/backups/
/usr/local/bin/mc-crossplay-update.sh
/usr/local/bin/mc-crossplay-watchdog.sh; echo "Exit: $?"
/usr/local/bin/mc-os-update.sh
```

### OS-Sicherheitsupdates einrichten (einmalig, beide Distros)

```bash
apt install -y unattended-upgrades
systemctl disable --now apt-daily-upgrade.timer   # wir steuern das Anwenden per Cron, fuer saubere ntfy-Meldungen
```

> Debian braucht zusätzlich einen Blick in `/etc/apt/apt.conf.d/50unattended-upgrades`, ob `${distro_id}:${distro_codename}-security` in den Allowed-Origins steht (bei Ubuntu ist das Default). Details/Prüfbefehl: [docs/06-wartung](../06-wartung/).

### Cronjobs

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

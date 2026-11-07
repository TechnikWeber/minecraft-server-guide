# B – Crossplay-Server: Java + Bedrock + Plugins (Debian/Ubuntu, Proxmox LXC oder VServer)

Die komplette Anleitung für einen **Crossplay-Server**: Java-Spieler am PC und Bedrock-Spieler auf Handy, Tablet und Windows spielen gemeinsam auf einer Welt. Dazu ein durchdachter Plugin-Stack für Komfort, Rechte und Schutz. Automatische Updates mit Rollback, tägliche Backups, Überwachung und ntfy-Benachrichtigungen sind von Anfang an dabei.

**Der Stack:** PaperMC 26.3 · Geyser + Floodgate (Zugang für Bedrock) · ViaVersion/ViaBackwards (andere Java-Versionen) · LuckPerms · Vault · EssentialsX · CoreProtect · GriefPrevention · Chunky

> **Die wichtigste Regel dieses Wegs: Geyser und die Plugins sind der limitierende Faktor.** Wir nutzen Paper **26.3** (Stand November 2026) — Geyser unterstützt nativ genau diese Java-Version. Zwei Plugins hängen noch hinterher: **EssentialsX** hat für 26.3 bisher nur Dev-Builds, **CoreProtect** 24.1 **startet auf 26.3 nicht** (siehe [Schritt 10](#schritt-10--plugin-stack-installieren)). Beide sind optional — Paper, Geyser, Floodgate und ViaVersion/ViaBackwards sind der Kern, alles andere lässt sich weglassen. Reihenfolge bei jedem größeren Sprung: **erst prüfen, ob Geyser und alle Plugins die Zielversion können, dann Paper.** Java-Clients mit neueren Versionen können sich trotzdem verbinden — dafür sorgen ViaVersion und ViaBackwards.

> Nur Bedrock-Geräte, keine Plugins nötig? Dann reicht der schlankere Weg **[A – Bedrock](../a-bedrock/)**.

Alle Befehle laufen **als root im LXC** bzw. auf dem VServer. Wo der Benutzer `minecraft` gebraucht wird, steht `su - minecraft` im Befehlsblock.

## Inhalt

1. **[Vorbereitung](#teil-1--vorbereitung)** — LXC oder VServer, Zeitzone, Pakete, Java 25, Repo, Benutzer
2. **[Server installieren](#teil-2--server-installieren)** — Paper, Geyser, Plugins, Konfiguration, systemd, Firewall, OP-Rechte, Chunky
3. **[Automatik](#teil-3--automatik)** — Config, Scripts, OS-Updates, Cronjobs
4. **[Sicherheit und Kinderserver](#teil-4--sicherheit-und-kinderserver)** — Whitelist, Gamemodes, Claims, Kinderserver-Profil, Gamerules, Starter-Kit
5. **[Plugins und Befehle](#teil-5--plugins-und-befehle)**
6. **[Wartung und Troubleshooting](#teil-6--wartung-und-troubleshooting)**
7. **[Erweiterungen](#teil-7--erweiterungen)**
8. **[Weitere Empfehlungen](#weitere-empfehlungen)**

Zum Weitergeben an die Spieler: **[Spieler-Anleitung](spieler-anleitung.md)** · **[dieselbe für Discord](spieler-anleitung-discord.md)** · **[Nachricht für Erwachsene/Freundeskreis](nachricht-erwachsene.md)**

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
- Bei statischer IP **das Gateway nicht vergessen** (Fritzbox: `192.168.178.1`). Ohne Gateway antwortet der Container zwar im Heimnetz und kommt oft sogar über IPv6 ins Internet — aber nicht über IPv4, und Spieler von außen bekommen keine Antwort. Prüfen im Container: `ip route | grep default` muss `default via 192.168.178.1` zeigen
- In der Fritzbox taucht ein Container mit statischer IP manchmal nur als **`PC---be24-11ff-fe…`** ohne IPv4-Adresse auf (der Name stammt aus der MAC, `BC:24:11:…` ist Proxmox). Unter *Heimnetz → Netzwerk* bearbeiten: sprechend umbenennen, IPv4-Adresse eintragen — erst dann lassen sich Portfreigaben sauber darauf legen
- `features: nesting=1` ist bei aktuellen Templates meist schon voreingestellt

Im Proxmox-LXC ist man standardmäßig root. Auf einem klassischen Ubuntu-Server außerhalb eines LXC zuerst `sudo -i`.

> **SSH in den LXC** (bequemer als die Proxmox-Konsole): in der Proxmox-Konsole des Containers `apt install -y openssh-server`, dann den eigenen **öffentlichen** Schlüssel (`~/.ssh/id_ed25519.pub` vom PC) nach `/root/.ssh/authorized_keys` kopieren (`mkdir -p /root/.ssh && chmod 700 /root/.ssh`, Datei `chmod 600`). Debian/Ubuntu lassen root ab Werk nur per Schlüssel rein, nicht per Passwort — genau richtig so.

### Alternative: VServer statt LXC

Kein Proxmox zu Hause? Die Anleitung funktioniert genauso auf einem gemieteten VServer (VPS). Scripts, systemd-Unit und Cronjobs laufen dort unverändert. Anders ist nur, was in diesem Abschnitt steht — danach geht es normal mit [Schritt 2](#schritt-2--uhrzeit-und-zeitzone-prüfen) weiter. An den späteren Stellen, an denen es einen Unterschied gibt, steht ein kurzer Hinweis **„Auf dem VServer"**.

**Welcher VServer?**

| | |
|---|---|
| Architektur | **x86_64 (amd64)** empfohlen. ARM (z.B. Hetzner CAX, netcup ARM) geht mit Java grundsätzlich auch, ist mit dieser Anleitung aber nicht getestet |
| RAM | **8 GB** (6 GB als Minimum, wie bei der LXC) |
| Image | **Ubuntu 24.04** oder **Debian 13**, wie bei der LXC |
| Günstige Beispiele (Stand September 2026, inkl. MwSt.) | **netcup VPS 1000 G12** (4 Kerne, 8 GB, 256 GB): 10,36 €/Monat bei 12 Monaten Laufzeit, 11,26 € monatlich kündbar · **Hetzner CX33** (4 Kerne, 8 GB, 80 GB): ca. 10,70 €/Monat inkl. IPv4, stundengenau abgerechnet und jederzeit kündbar |

Beim Bestellen deinen **SSH-Schlüssel** hinterlegen, falls der Anbieter das anbietet. Noch keinen? Auf dem eigenen PC `ssh-keygen -t ed25519` ausführen (unter Windows genauso in der PowerShell) — der öffentliche Teil liegt danach in `~/.ssh/id_ed25519.pub`.

#### Anmelden und Architektur prüfen

```bash
ssh root@DEINE-SERVER-IP
dpkg --print-architecture   # sollte "amd64" zeigen
```

Meldest du dich mit einem anderen Benutzer an als `root`: zuerst `sudo -i`.

#### SSH absichern — als Allererstes

Ein VServer hängt direkt im Internet, Bots probieren ab der ersten Minute Passwörter durch. Deshalb erlaubst du nur noch die Anmeldung per Schlüssel.

Liegt dein Schlüssel noch nicht auf dem Server, **vom eigenen PC aus** hochladen:

```bash
# Linux/macOS:
ssh-copy-id root@DEINE-SERVER-IP
# Windows (PowerShell):
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@DEINE-SERVER-IP "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Dann **auf dem Server** Passwort-Anmeldungen abschalten:

```bash
cat > /etc/ssh/sshd_config.d/00-minecraft-guide.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
sshd -t && systemctl restart ssh
sshd -T | grep -i '^passwordauthentication'   # muss "passwordauthentication no" zeigen
```

> Der Dateiname beginnt mit `00`, weil bei SSH die **erste** Angabe gewinnt — so setzt er sich auch gegen eine `50-cloud-init.conf` durch, mit der manche Images Passwörter wieder erlauben.

> **Nicht aussperren:** Die aktuelle Verbindung offen lassen und in einem **zweiten Terminal** testen, ob `ssh root@DEINE-SERVER-IP` noch klappt. Geht gar nichts mehr: Jeder Anbieter hat im Kundenmenü eine Web-Konsole (netcup: Server Control Panel, Hetzner: Console), darüber kommst du ohne SSH auf den Server.

#### Swap als Notreserve

VServer-Images kommen meist ohne Swap. Läuft der RAM voll, beendet Linux sonst einfach den größten Prozess — und das ist Java mit deinem Server. 2 GB Swap fangen solche Spitzen ab:

```bash
free -h   # steht bei "Swap" 0B, anlegen:
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

> Swap ist nur das Sicherheitsnetz. Wird er dauerhaft genutzt (`free -h`), ist `-Xmx` zu hoch gesetzt oder der VServer zu klein.

#### Was auf dem VServer sonst anders ist

| Stelle | LXC zu Hause | VServer |
|---|---|---|
| Proxmox-Einstellungen (oben) | „Start at boot", feste IP | entfällt — der Dienst startet per systemd von selbst, die öffentliche IP ist fest |
| [Schritt 15](#schritt-15--systemd-service) – `-Xmx` | RAM der LXC minus ca. 1,5 GB | RAM des VServers minus ca. 1,5 GB, bei 8 GB also `-Xmx6G` |
| [Schritt 16](#schritt-16--firewall-und-port-forwarding) – Firewall | Port-Forwarding im Router | kein Router; SSH mit `ufw limit`, ggf. Firewall des Anbieters |
| [Whitelist](#stufe-1--wer-darf-rein-whitelist) | sinnvoll | **dringend empfohlen** — der Server ist für die ganze Welt erreichbar |
| Snapshots | `pct snapshot` | im Kundenmenü des Anbieters |
| Kernel | kommt vom Host | eigener Kernel — **automatischer Neustart empfohlen**, siehe [Automatischer Neustart](#automatischer-neustart-nur-vserver) |
| Überwachung | Watchdog + ntfy | zusätzlich ein [externer Uptime-Check](#externer-uptime-check), weil ein ausgefallener VServer selbst nichts mehr melden kann |
| Backups | liegen im LXC | liegen auf dem VServer — [Off-Site-Backup](#weitere-empfehlungen) einplanen |
| Spieler verbinden sich mit | DDNS-Name oder IP des Anschlusses | IP des VServers (oder eigene Domain mit A-Record) |

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
apt install -y curl wget unzip jq file ufw logrotate git cron ca-certificates gnupg
```

`curl` und `wget` für Downloads, `unzip` und `file` zum Prüfen der JARs, `jq` für den Update-Check, `ufw` als Firewall, `logrotate` für die Logs, `git` für dieses Repo, `cron` für die Automatik aus Teil 3 (fehlt in manchen Debian-13-Images), `ca-certificates` und `gnupg` für das Java-Repository. Auf beiden Distros identisch.

### Schritt 4 – Java 25 installieren

Paper 26.3 braucht **Java 25** (Pflicht ab Minecraft 26.1). Weder Ubuntu 24.04 noch Debian 13 haben das im Standard-Repository — daher über das Adoptium-Repository (Eclipse Temurin). Der Block ist auf beiden Distros identisch, weil er den Codenamen automatisch ausliest:

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
  "https://fill-data.papermc.io/v1/objects/9601f9a26a2a52a0f2c807cf1abf691f96ee4fb287878313b601cebc2c51eabf/paper-26.3-244.jar"
chown -R minecraft:minecraft /home/minecraft/paper
```

Die Datei sollte 50–60 MB groß sein. Falls der Link abläuft: [papermc.io/downloads/paper](https://papermc.io/downloads/paper) → Version **26.3** wählen → Download-Link kopieren. Ein älterer Build ist kein Problem — das Auto-Update aus Teil 3 zieht nach.

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
  "https://hangarcdn.papermc.io/plugins/ViaVersion/ViaVersion/versions/5.12.2/PAPER/ViaVersion-5.12.2.jar"
wget -O ViaBackwards.jar \
  "https://hangarcdn.papermc.io/plugins/ViaVersion/ViaBackwards/versions/5.12.2/PAPER/ViaBackwards-5.12.2.jar"

ls -lh *.jar && file *.jar   # "Java archive data (JAR)" oder "Zip archive data" - nie HTML/ASCII text
```

> ViaVersion und ViaBackwards **immer in derselben Version** und aus demselben Channel (Release) ziehen, nie mischen.
>
> **Alte, angreifbare Protokolle sperren:** ViaVersion warnt beim Start, dass die Clients 1.20.5–1.21.4 leicht angreifbar sind. Wer sie nicht braucht, trägt nach dem ersten Start in `plugins/ViaVersion/config.yml` ein: `block-versions: ["1.20.5-1.20.6", "1.21-1.21.1", "1.21.2-1.21.3", "1.21.4"]` — wirksam nach `/viaversion reload`.
>
> **ViaVersion aktuell halten!** Es wird nicht automatisch aktualisiert. Ist es zu alt für die neueste Java-Version, kommen Windows-/Launcher-Spieler mit der Meldung „Inkompatible Version" bzw. der Paper-Versionsnummer nicht mehr rein. Beispiel: Java 26.3 braucht mindestens ViaVersion 5.12.0.

### Schritt 10 – Plugin-Stack installieren

Weiter als `minecraft` im `plugins`-Ordner. Was die Plugins tun und woher neuere Versionen kommen: **[Teil 5](#teil-5--plugins-und-befehle)**.

> **Der ganze Schritt ist optional.** Für Crossplay reichen Paper, Geyser, Floodgate und ViaVersion/ViaBackwards aus [Schritt 9](#schritt-9--geyser-floodgate-viaversion-und-viabackwards). Die Plugins hier bringen Komfort und Schutz — einzeln weglassen geht, nur Vault wird von EssentialsX-Economy und Chat-Präfixen gebraucht.

```bash
# LuckPerms, Vault, EssentialsX (+Spawn +Chat), CoreProtect, GriefPrevention, Chunky
# Feste Links mit Versionsnummer, fuer Paper 26.3 geprueft (Stand November 2026).
# EssentialsX: siehe Hinweis unter dem Block!
# CoreProtect fehlt bewusst: 24.1 startet auf 26.3 nicht (Hinweis unten).
wget -O LuckPerms.jar        "https://cdn.modrinth.com/data/Vebnzrzj/versions/b0mk8uS6/LuckPerms-Bukkit-5.5.71.jar"
wget -O Vault.jar            "https://github.com/MilkBowl/Vault/releases/download/1.7.3/Vault.jar"
# wget -O CoreProtect.jar   "<Link zur ersten Version mit 26.3-Support>"
wget -O GriefPrevention.jar  "https://cdn.modrinth.com/data/O4o4mKaq/versions/MtwPHMAS/GriefPrevention.jar"
wget -O Chunky.jar           "https://cdn.modrinth.com/data/fALzjamp/versions/RBuKjN4k/Chunky-Paper-1.5.66.jar"
wget -O EssentialsX.jar      "https://ci.ender.zone/job/EssentialsX/1833/artifact/jars/EssentialsX-2.22.1-dev%2B28-f8724e2.jar"
wget -O EssentialsXSpawn.jar "https://ci.ender.zone/job/EssentialsX/1833/artifact/jars/EssentialsXSpawn-2.22.1-dev%2B28-f8724e2.jar"
wget -O EssentialsXChat.jar  "https://ci.ender.zone/job/EssentialsX/1833/artifact/jars/EssentialsXChat-2.22.1-dev%2B28-f8724e2.jar"

ls -lh ~/paper/plugins && file ~/paper/plugins/*.jar
exit   # zurueck zu root
```

**Jede** Datei muss als `Java archive data (JAR)` oder `Zip archive data` erkannt werden (eine JAR ist ein ZIP). Steht dort `HTML document` oder `ASCII text`, war der Download eine Fehlerseite. Die Größe sagt wenig: EssentialsXSpawn hat nur rund 20 KB, EssentialsX knapp 5 MB.

> **Stand November 2026 — zwei Plugins mit Vorbehalt:**
> - **EssentialsX:** Das letzte offizielle Release 2.22.0 unterstützt nur bis 26.1.2. Für 26.3 gibt es bisher nur **Dev-Builds** vom offiziellen Build-Server (oben: Build 1833, enthält „Update to Minecraft 26.3"). Dev-Builds sind nicht final getestet. Sobald 2.22.1 oder neuer als Release erscheint, auf [essentialsx.net/downloads.html](https://essentialsx.net/downloads.html) wechseln.
> - **CoreProtect 24.1** verweigert auf 26.3 den Start: Im Log steht `[CoreProtect] Minecraft 26.3 is not supported.` und das Plugin schaltet sich ab (getestet November 2026). Bis eine Version mit 26.3-Support erscheint ([Modrinth](https://modrinth.com/plugin/coreprotect/versions)), gibt es kein Block-Protokoll und kein `/co rollback` — als Netz bleiben die täglichen Backups. Neue Version dann wie in [Paper und Plugins von Hand aktualisieren](#paper-und-plugins-von-hand-aktualisieren) einspielen und `/co status` prüfen.

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

#### Was Minecraft ab Werk einstellt

Bevor man etwas ändert: Diese Werte prägen das Spielgefühl am stärksten. Gamerules gelten pro Welt und werden ingame (oder per [mc-cmd](#bequemer-konsole-per-rcon)) gesetzt.

| Einstellung | Standard | Ändern mit | Hinweis |
|---|---|---|---|
| Schwierigkeit | `easy` | `difficulty=` in `server.properties` | `peaceful` = keine Monster, kein Hunger |
| **Schlafen** | **alle** müssen schlafen | `/gamerule players_sleeping_percentage 0` | `0` = einer reicht — im Mehrspieler die beliebteste Änderung |
| Inventar beim Tod | geht verloren (Items 5 Min. am Todesort) | `/gamerule keep_inventory true` | |
| PvP | an | `/gamerule pvp false` | |
| Creeper/Endermen verändern Blöcke | an | `/gamerule mob_griefing false` | schaltet auch Dorfbewohner-Ernte ab |
| Tag/Nacht · Wetter | an | `/gamerule advance_time false` · `advance_weather false` | |
| Spawn-Streuung | bis 10 Blöcke um den Spawn | `/gamerule respawn_radius 0` | `0` = alle erscheinen genau auf dem Spawn |
| Sichtweite · Simulation | 10 · 10 Chunks | `view-distance=` · `simulation-distance=` | Obergrenze — jeder Spieler kann im Client weniger einstellen, nicht mehr. Mit 6 GB RAM sind 12 · 10 gut machbar |
| Max. Spieler | 20 | `max-players=` | |

### Schritt 12 – Einmal starten, damit die Plugins ihre Configs anlegen

```bash
su - minecraft
cd ~/paper
java -Xms2G -Xmx4G -jar paper.jar --nogui
```

Das Log sollte u.a. zeigen: `[LuckPerms] Successfully enabled`, `[CoreProtect] Enabled`, `[GriefPrevention] ... enabled`, `[Essentials] Enabled`, `[floodgate] ... Floodgate`, `[Geyser-Spigot] Built-in signaling started on http://0.0.0.0:19132`, `[ViaVersion] Loading ViaVersion`. Dann `stop` und `exit`.

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
bedrock:
  port: 19132
  transport: nethernet   # seit 27.10.2026 Pflicht fuer aktuelle Bedrock-Clients
  signaling:
    mode: builtin
java:
  auth-type: floodgate   # <- der wichtigste Punkt
```

> **NetherNet:** Seit dem 27. Oktober 2026 verbinden sich Bedrock-Clients über das neue Protokoll NetherNet. Aktuelle Geyser-Builds stellen das von selbst ein — prüfen schadet nicht. Geyser braucht dafür auf Port 19132 **UDP und TCP** (TCP für den Verbindungsaufbau, UDP fürs Spielen), siehe [Schritt 16](#schritt-16--firewall-und-port-forwarding). `clone-remote-port: true` funktioniert damit nicht mehr, weil TCP 25565 schon vom Java-Server belegt ist. Hintergrund: [GeyserMC – Preparing for NetherNet](https://geysermc.org/blog/preparing-for-nethernet/).

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

> **Erst verknüpfen, dann OP und Freischaltung.** Nach der Verknüpfung nutzt der Bedrock-Client das Java-Konto — ein `op JavaName` gilt dann für beide Geräte. Was jemand vorher mit Bedrock gesammelt hat, gehört dem getrennten Bedrock-Konto und ist nach der Verknüpfung nicht mehr da. Deshalb gleich beim ersten Login verknüpfen.

### Schritt 15 – systemd-Service

```bash
cd /opt/minecraft-server-guide
cp systemd/minecraft-paper.service /etc/systemd/system/minecraft-paper.service
nano /etc/systemd/system/minecraft-paper.service   # -Xmx anpassen: RAM der LXC bzw. des VServers minus ca. 1,5 GB
systemctl daemon-reload
systemctl enable --now minecraft-paper
journalctl -u minecraft-paper -n 50
```

Nach etwa einer Minute sollte im Log `Done (...)` stehen.

### Schritt 16 – Firewall und Port-Forwarding

```bash
ufw allow 22/tcp        # SSH zuerst, sonst sperrst du dich aus!
ufw allow 25565/tcp     # Java
ufw allow 19132/udp     # Bedrock ueber Geyser (Spielen)
ufw allow 19132/tcp     # Bedrock ueber Geyser (NetherNet-Verbindungsaufbau)
ufw enable
```

Router: **TCP** 25565 → 25565, **UDP** 19132 → 19132 und **TCP** 19132 → 19132, alle auf die feste LXC-IP aus [Schritt 1](#schritt-1--lxc-anlegen) (`ip a | grep inet` zeigt sie). Kommt von außen nichts an: CGNAT prüfen, siehe [Weitere Empfehlungen](#weitere-empfehlungen).

> **Port 19132 braucht UDP und TCP.** Früher reichte UDP — seit NetherNet (27.10.2026) scheitern Bedrock-Clients ohne TCP 19132 mit „Initial Connection"-Fehlern, und im Server-Log taucht gar kein Verbindungsversuch auf. In der Fritzbox ist das eine eigene, dritte Freigabe. Bei IPv6-Freigaben prüfen, ob die Interface-ID in der Fritzbox noch zur aktuellen Adresse des Containers passt (`ip a show eth0`) — nach einem Neuanlegen des Containers ändert sie sich.
>
> Test von außen bzw. über die öffentliche Adresse: `timeout 5 bash -c 'echo > /dev/tcp/DEINE-DOMAIN/19132' && echo offen`

> **Auf dem VServer:** `ufw limit 22/tcp` statt `ufw allow 22/tcp` — sperrt eine IP, die 6 oder mehr Verbindungen in 30 Sekunden versucht, und bremst so Passwort-Rater zusätzlich aus. Router und Port-Forwarding entfallen. Hat der Anbieter im Kundenmenü eine eigene Firewall aktiv (z.B. Hetzner Cloud Firewall), dort **TCP** 22, **TCP** 25565, **UDP** 19132 und **TCP** 19132 ebenfalls freigeben.

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

#### Bequemer: Konsole per RCON

Statt den Server für jeden Konsolen-Befehl von Hand zu starten, kann man Befehle per RCON an den laufenden Server schicken. Das Script `mc-cmd` aus diesem Repo erledigt das von root aus:

```bash
nano /home/minecraft/paper/server.properties
#   enable-rcon=true
#   rcon.port=25575
#   rcon.password=<langes Zufallspasswort, z.B. aus: openssl rand -base64 24>
#   broadcast-rcon-to-ops=false
chmod 640 /home/minecraft/paper/server.properties
install -m 750 /opt/minecraft-server-guide/scripts/common/mc-cmd /usr/local/bin/mc-cmd
systemctl restart minecraft-paper
mc-cmd op DeinJavaName
mc-cmd list
```

> Port 25575 **nicht** in `ufw` oder im Router freigeben — RCON soll nur auf dem Server selbst erreichbar sein. `ufw` aus [Schritt 16](#schritt-16--firewall-und-port-forwarding) blockt ihn ab Werk.

### Schritt 18 – Welt mit Chunky vorgenerieren

Chunks „on the fly" zu erzeugen ist der größte Lag-Verursacher bei Crossplay, weil Java- und Bedrock-Clients unterschiedlich nachladen. Chunky erzeugt das Gelände einmal im Voraus — vorher den Spawn festlegen, denn er wird der Mittelpunkt.

**Spawn suchen und setzen** (als OP, bevor die anderen kommen):

```
/gamemode spectator                  # fliegen, durch Blöcke, kein Inventar
/setworldspawn                       # am gewünschten Ort, setzt den Spawn auf die eigene Position
/advancement revoke @s everything    # unterwegs "geschenkte" Fortschritte zurücksetzen
/gamemode survival
```

> Der Zuschauermodus ist besser als Creative: Im Creative-Modus vergibt Java weiter Fortschritte (z.B. für Items aus dem Kreativ-Menü). Kaputt geht dadurch nichts, `/advancement revoke @s everything` setzt sie zurück. Festen Boden für den Spawn wählen (kein Wasser, kein Laub, keine Höhle darunter). Der Spawn gilt für neue Spieler und für alle, die ohne Bett sterben. Gefällt gar nichts: Welt neu würfeln, siehe [Welt zurücksetzen oder neu würfeln](#welt-zurücksetzen-oder-neu-würfeln).

**Vorgenerieren** — mit den Koordinaten des Spawns statt `X Z`:

```
/chunky world world
/chunky center X Z
/chunky radius 3000
/chunky start
```

`/chunky pause` · `/chunky continue` · `/chunky progress` · `/chunky cancel`. Faustregel: Radius 3000 ≈ 6 × 6 km, reicht für die meisten privaten Server. Am besten laufen lassen, wenn niemand online ist.

> **Fortschritt aufs Handy (optional):** `scripts/crossplay/mc-chunky-ntfy.sh` meldet alle 5 % per ntfy, startet danach selbst Nether und End und nimmt sich am Ende aus dem Cron. Braucht [mc-cmd](#bequemer-konsole-per-rcon). In der Datei `STAGES` anpassen (Mitte = Spawn, Nether = Spawn-Koordinaten / 8), dann:
>
> ```bash
> install -m 750 /opt/minecraft-server-guide/scripts/crossplay/mc-chunky-ntfy.sh /usr/local/bin/mc-chunky-ntfy.sh
> nano /usr/local/bin/mc-chunky-ntfy.sh   # STAGES anpassen
> (crontab -l; echo "*/2 * * * * /usr/local/bin/mc-chunky-ntfy.sh >> /var/log/mc-chunky-ntfy.log 2>&1") | crontab -
> ```
>
> Nach „alles fertig": `Chunky.jar` und `plugins/Chunky/` löschen, Server neu starten — Chunky wird danach nicht mehr gebraucht.

> **Mittelpunkt = Spawn:** Erst den Spawn festlegen (`/setworldspawn` am gewünschten Ort), dann mit dessen Koordinaten `/chunky center X Z`. Mit einer Browser-Karte wie [BlueMap](#karte-im-browser-bluemap) unbedingt `min-inhabited-time` setzen, sonst zeigt die Karte die ganze vorgenerierte Welt.

> **Nether und End:** Seit Paper 26.1 liegen sie im Weltordner (`world/dimensions/minecraft/the_nether` bzw. `the_end`). Ältere Chunky-Versionen konnten sie dort nicht auswählen ([Chunky-Issue #480](https://github.com/pop4959/Chunky/issues/480)), laut Issue ist das in aktuellen Versionen behoben (verlinkt ist 1.5.66): `/chunky world ` tippen und den Nether bzw. das End per Tab-Vervollständigung wählen, dann wie oben (im Nether reicht ein kleinerer Radius, z.B. 1000).

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

# Nur VServer: sonntags um 06:00 neu starten, falls ein Neustart ansteht
0 6 * * 0 [ -f /var/lib/minecraft-guide/reboot-pending ] && /sbin/shutdown -r now
```

> **Auf dem VServer:** die letzte Zeile mit eintragen, Hintergrund: [Automatischer Neustart](#automatischer-neustart-nur-vserver). In der LXC weglassen.

### Was automatisch läuft und was nicht

| Aufgabe | Automatisch? | Details |
|---|---|---|
| Watchdog | ✅ alle 5 Minuten | Startet einen abgestürzten Server neu, wartet bis Paper wirklich bereit ist, meldet nur Zustandswechsel |
| Backup | ✅ täglich 03:30 | Welt samt Nether und End, Paper- und Plugin-Configs, Daten von LuckPerms, GriefPrevention, CoreProtect und Essentials, Floodgate-Schlüssel · aufbewahrt 7 Tage (`BACKUP_KEEP_DAYS` in der Config) |
| OS-Sicherheitsupdates | ✅ täglich 04:00 | Neustart wird nur **gemeldet**, nicht erzwungen — auf dem VServer empfohlen: automatisch sonntags, siehe [Automatischer Neustart](#automatischer-neustart-nur-vserver) |
| Geyser + Floodgate | ✅ täglich 05:00 | Müssen mit Bedrock-Client-Updates Schritt halten |
| Paper-Builds **innerhalb** von 26.3 | ✅ täglich 05:00 | Patch-Builds sind sicher · vorher Backup, bei Fehlstart automatischer Rollback |
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

> **Minecraft Java hat die Gamerules mit 1.21.11 umbenannt** (z.B. `doDaylightCycle` → `advance_time`). Alte Anleitungen im Netz nennen oft noch die alten Namen — die funktionieren auf Paper 26.x nicht mehr. Im Zweifel `/gamerule ` tippen, die Tab-Vervollständigung zeigt die gültigen Namen.

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

Die in [Schritt 10](#schritt-10--plugin-stack-installieren) verlinkten Versionen sind für Paper 26.3 geprüft (Stand November 2026; EssentialsX nur als Dev-Build, CoreProtect noch ohne 26.3-Version). Für neuere Versionen immer auf der offiziellen Seite die **zur Paper-Version passende** wählen:

| Plugin | Quelle |
|---|---|
| LuckPerms | [luckperms.net/download](https://luckperms.net/download) (Variante **Bukkit**) |
| Vault | [github.com/MilkBowl/Vault/releases](https://github.com/MilkBowl/Vault/releases) — letztes Release 2020; bei Problemen ist [VaultUnlocked](https://modrinth.com/plugin/vaultunlocked) der gepflegte Nachfolger |
| EssentialsX | [essentialsx.net/downloads.html](https://essentialsx.net/downloads.html) — Module `EssentialsX`, `EssentialsXSpawn`, `EssentialsXChat`; Dev-Builds auf [ci.ender.zone](https://ci.ender.zone/job/EssentialsX/) |
| CoreProtect | [modrinth.com/plugin/coreprotect](https://modrinth.com/plugin/coreprotect/versions) |
| GriefPrevention | [github.com/TechFortress/GriefPrevention/releases](https://github.com/TechFortress/GriefPrevention/releases) bzw. [Modrinth](https://modrinth.com/plugin/griefprevention) |
| Chunky | [hangar.papermc.io/pop4959/Chunky](https://hangar.papermc.io/pop4959/Chunky) bzw. [modrinth.com/plugin/chunky](https://modrinth.com/plugin/chunky) — Plattform **Paper** |

Downloads immer prüfen: `file ~/paper/plugins/*.jar` muss `Java archive data (JAR)` oder `Zip archive data` zeigen, nicht `ASCII text` oder `HTML` (= Fehlerseite).

> **CoreProtect** legt beim ersten Start eine SQLite-Datenbank in `plugins/CoreProtect/` an. Sie wächst mit der Zeit und ist im Backup enthalten — für einen privaten Server reicht SQLite locker.

### Befehle eingeben

Ingame im Chat mit `/` — Bedrock-Spieler tippen sie genauso. In der Server-Konsole (nur beim Start von Hand, siehe [Schritt 17](#schritt-17--op-rechte-vergeben)) ohne `/`. Vom Server aus ohne Neustart: [mc-cmd](#bequemer-konsole-per-rcon).

### Skins und Erfolge – was Spieler fragen

- **Skins:** Java-Spieler sehen alle Java-Skins wie gewohnt, Bedrock-Spieler sehen alle Skins. Bedrock-Skins lädt Geyser für die Java-Spieler hoch — gekaufte Marketplace- und Charakter-Ersteller-Skins erscheinen dort als **flaches Standardmodell** (Farben und Muster stimmen, 3D-Teile wie Hüte oder Flügel fehlen). Nach dem Einloggen kann das ein paar Minuten dauern.
- **Erfolge:** Die Java-Fortschritte (Advancements) funktionieren für alle — Bedrock-Spieler sehen sie über `/advancements` als Menü. **Xbox-Erfolge** gibt es auf eigenen Servern nicht; Geysers Schalter `xbox-achievements-enabled` funktioniert nur teilweise und bleibt besser aus.

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

### Neustart aus dem Chat

Ab Werk startet systemd den Server nur nach einem Absturz neu — ein `/stop` oder `/restart` im Spiel lässt ihn aus, bis der Watchdog nach bis zu 5 Minuten eingreift. Mit einer kleinen Ergänzung kommt der Server immer sofort wieder:

```bash
mkdir -p /etc/systemd/system/minecraft-paper.service.d
cat > /etc/systemd/system/minecraft-paper.service.d/restart.conf <<'EOF'
[Service]
Restart=always
RestartSec=5
EOF
systemctl daemon-reload
```

Danach reicht OPs **`/restart`** (oder `/stop`) im Chat — nach etwa 40 Sekunden ist der Server zurück. Die Meldung `Startup script './start.sh' does not exist! Stopping server.` im Log ist dabei normal: Paper fährt herunter, systemd startet neu. `systemctl stop minecraft-paper` hält den Server weiterhin richtig an.

**Auslastung im Spiel:** Paper bringt **spark** mit — `/spark health` (CPU, RAM, TPS), `/spark tps`, `/spark profiler` (Analyse als Weblink). Nur für OPs.

### Weboberfläche für den Notfall: Cockpit

Hängt der Server so, dass auch der Chat nicht mehr geht, hilft [Cockpit](https://cockpit-project.org/) — die offizielle Server-Weboberfläche von Debian/Ubuntu: Buttons für Start/Stopp/Neustart des Dienstes, CPU-/RAM-/Plattenanzeige und die Logs. Für alle OPs gibt es einen gemeinsamen Benutzer, der **nur** den Minecraft-Dienst steuern und Logs lesen darf — keine Root-Rechte.

```bash
apt install -y --no-install-recommends cockpit-ws cockpit-system cockpit-bridge polkitd
systemctl enable --now cockpit.socket

useradd -m -s /bin/bash -c "Minecraft-Admin (Cockpit)" mcadmin
usermod -aG systemd-journal mcadmin      # darf Logs lesen
passwd mcadmin                           # langes Passwort, z.B. 4 x 5 Zeichen mit Bindestrichen
echo "DenyUsers mcadmin" > /etc/ssh/sshd_config.d/10-deny-mcadmin.conf   # kein SSH fuer mcadmin

cat > /etc/polkit-1/rules.d/50-mcadmin-minecraft.rules <<'EOF'
// mcadmin darf nur den Minecraft-Dienst starten/stoppen/neu starten, sonst nichts.
polkit.addRule(function(action, subject) {
  if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "mcadmin") {
    var unit = action.lookup("unit"), verb = action.lookup("verb");
    if (unit == "minecraft-paper.service" && (verb == "start" || verb == "stop" || verb == "restart")) {
      return polkit.Result.YES;
    }
    return polkit.Result.NO;
  }
});
EOF
chmod 644 /etc/polkit-1/rules.d/50-mcadmin-minecraft.rules   # polkit muss sie lesen koennen!
systemctl restart polkit

ufw allow 9090/tcp
```

**Schutz gegen Passwort-Rater mit fail2ban** — sperrt eine Adresse nach 5 falschen Passwörtern für 1 Stunde, und zwar **nur für Port 9090**:

```bash
apt install -y fail2ban python3-systemd

cat > /etc/fail2ban/filter.d/cockpit.conf <<'EOF'
[Definition]
failregex = pam_unix\(cockpit:auth\): authentication failure;.*rhost=(?:::ffff:)?<HOST>(?:\s|$)
ignoreregex =
EOF

cat > /etc/fail2ban/jail.d/cockpit.local <<'EOF'
[cockpit]
enabled      = true
backend      = systemd
journalmatch = SYSLOG_IDENTIFIER=cockpit-session
filter       = cockpit
port         = 9090
banaction    = nftables-multiport
maxretry     = 5
findtime     = 10m
bantime      = 1h
EOF
systemctl restart fail2ban
fail2ban-client status cockpit
```

> **Nicht `ufw limit 9090/tcp` nehmen:** Das zählt jede Verbindung, und ein Browser öffnet beim Laden von Cockpit mehr als die erlaubten 6 in 30 Sekunden — die Seite lädt dann von außen nicht. **Nicht `banaction = ufw` nehmen:** Diese Aktion sperrt die Adresse für **alle** Ports, also auch SSH und Minecraft — bei Spielern aus demselben Heimnetz womöglich die gemeinsame öffentliche IP. Gesperrte Adresse wieder freigeben: `fail2ban-client set cockpit unbanip <IP>`.

Testen: `su -s /bin/bash mcadmin -c "systemctl --no-ask-password restart cron"` muss **Access denied** melden, dieselbe Zeile mit `minecraft-paper` muss klappen. root darf sich an Cockpit ab Werk nicht anmelden (`/etc/cockpit/disallowed-users`).

Aufruf: `https://<Server-IP>:9090`, für OPs von außen im Router **TCP** 9090 freigeben → `https://DEINE-DOMAIN:9090`. Beim ersten Aufruf warnt der Browser vor dem selbst ausgestellten Zertifikat — einmal „trotzdem fortfahren". In Cockpit unter **Dienste → minecraft-paper** gibt es die Buttons, unter **Protokolle** die Logs.

> **Fehler finden:** Paper schreibt alles mit gleicher Priorität ins Journal — der Prioritätsfilter „Fehler" in Cockpit zeigt Paper-Fehler deshalb nicht. Stattdessen unter *Protokolle* nach `ERROR` oder `Exception` suchen (Textfeld).
>
> **Öffentlich oder nur per VPN?** Sicherer ist es, Port 9090 nicht freizugeben und von unterwegs per VPN (FRITZ!Box-VPN, Tailscale) ins Heimnetz zu gehen. Öffentlich ist es bequemer; dann sind ein langes Passwort, der eingeschränkte Benutzer und fail2ban Pflicht.

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

**Paper-Versionssprung** (z.B. 26.3 → 26.4) — erst, wenn Geyser und alle Plugins so weit sind:

1. Prüfen, ob Geyser **und alle Plugins** (vor allem EssentialsX und CoreProtect) die Zielversion offiziell unterstützen.
2. Plugins bei Bedarf zuerst aktualisieren (siehe unten).
3. `PAPER_MC_VERSION` in `/etc/minecraft-guide.conf` anpassen.
4. `/usr/local/bin/mc-crossplay-update.sh` laufen lassen — holt den neuesten Build der neuen Version, mit Backup und Rollback.

> **Achtung:** Die Welt wird beim ersten Start mit der neuen Version **unumkehrbar** umgewandelt. Ein Rollback der JAR hilft danach nicht mehr — nur das Backup von vor dem Sprung. Vorher zusätzlich einen Snapshot machen (Proxmox: `pct snapshot <CTID> vor-paper-<version>`, VServer: im Kundenmenü). Ein Zurück auf die alte Paper-Version mit der umgewandelten Welt endet mit `No key dimensions in MapLike[{}]` — die Welt ist dann für die alte Version nicht mehr lesbar.
>
> **Sprung von 1.21.x auf 26.x:** Paper zeigt beim ersten Start `World storage migration is required` und wartet 30 Sekunden (zum Abbrechen, falls kein Backup da ist). Danach zieht es Nether und End aus den alten Ordnern `<welt>_nether` und `<welt>_the_end` nach `<welt>/dimensions/minecraft/` um — die alten Ordner verschwinden. Liegen mehrere Welten auf dem Server, wird jede erst beim ersten Laden umgewandelt.

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
| **Distro-Wechsel** (Ubuntu 24.04 → 26.04, Debian 13 → 14) | alle paar Jahre | Bewusst und mit Snapshot vorher (Proxmox: `pct snapshot <CTID> vor-upgrade`, VServer: im Kundenmenü des Anbieters); bei Ubuntu über `do-release-upgrade`, bei Debian über die Paketquellen auf den neuen Codenamen. |
| **Support-Ende der Distro** | nach ca. 5 Jahren | Ubuntu: **Ubuntu Pro** ist für Privatnutzung kostenlos und verlängert die Sicherheitsupdates um Jahre. Debian: Die LTS-Phase läuft automatisch über die normalen Paketquellen; danach gibt es nur noch kostenpflichtiges ELTS — rechtzeitig auf die nächste Version wechseln. |
| **Proxmox-Host-Updates** | gelegentlich | Laufen auf dem Host, nicht im LXC. Auf dem VServer kümmert sich der Anbieter darum. |
| **Kernel** | nach Kernel-Updates | LXC: kommt vom Host, nichts zu tun. VServer: Neustart nötig, empfohlen automatisch, siehe [Automatischer Neustart](#automatischer-neustart-nur-vserver). |

#### Automatischer Neustart (nur VServer)

Auf dem VServer hast du einen eigenen Kernel, und ein Kernel-Update wirkt erst nach einem Neustart. **Empfohlen** ist deshalb die Neustart-Zeile aus [Schritt 23](#schritt-23--cronjobs). Sie startet den Server **sonntags um 06:00** neu, aber nur, wenn wirklich ein Neustart ansteht:

```cron
0 6 * * 0 [ -f /var/lib/minecraft-guide/reboot-pending ] && /sbin/shutdown -r now
```

- Die Datei legt `mc-os-update.sh` an, sobald es einen nötigen Neustart meldet (als Hinweis in „Host: Sicherheitsupdates installiert" oder als eigene Meldung „Host: Neustart empfohlen"). Nach dem Neustart entfernt es sie wieder.
- **Sonntag 06:00** liegt bewusst nach Backup und Updates, damit nie eine laufende Installation abgebrochen wird — und morgens spielt kaum jemand. Täglich direkt nach dem Update wäre riskanter.
- Der Minecraft-Server startet danach von selbst, der Watchdog lässt ihm Zeit zum Hochfahren.
- Lieber selbst entscheiden? Zeile weglassen und nach der ntfy-Meldung zu einer ruhigen Zeit `reboot` ausführen. Danach prüfen: `journalctl -u minecraft-paper -n 20` muss `Done (` zeigen.

In der LXC ist das nicht nötig — dort kommt der Kernel vom Host.

##### Externer Uptime-Check

Watchdog und ntfy laufen **auf** dem Server. Fällt der ganze VServer aus (Neustart hängt, Störung beim Anbieter), kann er selbst nichts mehr melden. Ein kostenloser Dienst, der **von außen** prüft, schließt diese Lücke — z.B. **UptimeRobot** (Free-Plan für private Projekte, Prüfung alle 5 Minuten, Benachrichtigung per E-Mail):

- Monitor-Typ **Port** auf die IP des VServers, Port **25565**. Damit ist nicht nur der Server geprüft, sondern auch, dass Paper wirklich antwortet.

Wer zu Hause ohnehin einen Server hat: **Uptime Kuma** kann dasselbe und benachrichtigt auch direkt per ntfy.

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
| `Host: Neustart empfohlen` | Kernel oder Bibliotheken aktualisiert, kommt einmal pro Anlass. | Bei Gelegenheit `reboot` |
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
| Bedrock-Spieler kommen nicht rein (z.B. „Initial Connection"), Java-Spieler schon | **UDP und TCP** 19132 in `ufw` und im Router bzw. in der Firewall des Anbieters prüfen; im Log muss `Built-in signaling started on http://0.0.0.0:19132` stehen. Fehlt TCP 19132, kommt im Log gar kein Bedrock-Versuch an |
| Java-Spieler mit neuestem Launcher bekommen „Inkompatible Version" (zeigt die Paper-Version), ältere Clients kommen rein | ViaVersion und ViaBackwards zu alt für die neue Java-Version — aktualisieren, siehe [Paper und Plugins von Hand aktualisieren](#paper-und-plugins-von-hand-aktualisieren) |
| Bedrock-Spieler werden beim Chatten gekickt | `enforce-secure-profile=false` in `server.properties` prüfen |
| `/linkaccount` ist unbekannt | `enable-own-linking: true` und `floodgate-sqlite-database.jar` in `plugins/floodgate/` ([Schritt 14](#schritt-14--floodgate-kontoverknüpfung)) |
| Gamerule ist unbekannt | Seit 1.21.11 gelten neue Namen — `/gamerule ` tippen, Tab-Vervollständigung zeigt sie |
| Plugin lädt nicht | `file datei.jar` zeigt `HTML`/`ASCII text` statt `Java archive data`/`Zip archive data` → war eine Fehlerseite, Link neu kopieren; sonst prüfen, ob das Plugin die Paper-Version unterstützt |
| Von außen kommt niemand rein | Port-Forwarding und feste IP prüfen; CGNAT siehe [Weitere Empfehlungen](#weitere-empfehlungen) · VServer: `ufw status` und die Firewall im Kundenmenü des Anbieters prüfen |
| Container fehlt in der Fritzbox oder hat dort keine IPv4-Adresse | Gateway prüfen: `ip route \| grep default` im Container muss das Gateway zeigen, sonst in Proxmox unter *Network* eintragen. Eintrag `PC---be24-…` in der Fritzbox = der Container, umbenennen und IPv4 eintragen ([Schritt 1](#schritt-1--lxc-anlegen)) |
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

Download: [WorldEdit auf Hangar](https://hangar.papermc.io/EngineHub/WorldEdit/versions), [WorldGuard auf Modrinth](https://modrinth.com/plugin/worldguard/versions). Vorher prüfen, dass beide Paper 26.3 unterstützen.

### Discord-Anbindung

**DiscordSRV** verbindet den Minecraft-Chat mit einem Discord-Channel (in beide Richtungen) und meldet, wer kommt und geht. Passt gut zur [Discord-Version der Spieler-Anleitung](spieler-anleitung-discord.md). Einrichtung: Bot im Discord-Developer-Portal anlegen, Token in `plugins/DiscordSRV/config.yml` eintragen.

### Mehrere Welten

**Multiverse-Core** erlaubt mehrere Welten auf demselben Server — z.B. eine Survival- und eine separate Creative-Bauwelt, oder eine eigene Welt pro Kind. `/mv create <name> normal` legt eine Welt an, `/mv tp <name>` wechselt hinein. Chunky ([Schritt 18](#schritt-18--welt-mit-chunky-vorgenerieren)) lässt sich pro Welt einzeln anwenden.

### Server-Icon (Logo in der Serverliste)

Ein eigenes Logo erscheint in der **Java**-Serverliste (Bedrock zeigt bei keinem Server ein Icon). Paper erwartet genau **64 × 64 Pixel**, PNG, unter dem Namen `server-icon.png`:

```bash
# auf dem PC (ImageMagick), aus einem quadratischen Logo:
magick logo.png -resize 64x64 server-icon.png      # aeltere Versionen: convert statt magick
scp server-icon.png root@DEINE-SERVER-IP:/home/minecraft/paper/server-icon.png
# auf dem Server:
chown minecraft:minecraft /home/minecraft/paper/server-icon.png
systemctl restart minecraft-paper
```

> Ein Logo lässt sich z.B. per Bild-KI erstellen. Für ein Icon taugt ein einfaches Emblem mit wenig Text und hohem Kontrast — vor dem Verkleinern prüfen, ob es bei 64 Pixeln noch erkennbar ist. Keine offiziellen Minecraft-Logos oder Mojang-Schriften nachbauen lassen.

### Karte im Browser: BlueMap

[BlueMap](https://bluemap.bluecolored.de/) zeichnet die Welt als 3D-Karte, die im Browser läuft (auch am Handy): Basen, Wege, wo die anderen gerade sind. Standardmäßig nur die Oberfläche, Höhlen und Erze bleiben unsichtbar, den Seed verrät die Karte nicht.

```bash
cd /home/minecraft/paper/plugins
wget -O BlueMap.jar "https://cdn.modrinth.com/data/swbUV1cr/versions/uHQIrUdf/bluemap-5.29-paper.jar"   # 5.29, geprueft mit Paper 26.3
chown minecraft:minecraft BlueMap.jar
systemctl restart minecraft-paper   # legt plugins/BlueMap/ mit den Configs an
```

Danach drei Einstellungen in `/home/minecraft/paper/plugins/BlueMap/`:

| Datei | Einstellung | Warum |
|---|---|---|
| `core.conf` | `accept-download: true` | BlueMap lädt die Texturen aus dem offiziellen Minecraft-Client von Mojang — ohne Zustimmung rendert es nichts |
| `maps/*.conf` (alle drei) | `min-inhabited-time: 1` | **Wichtig gegen Spoiler:** nur Chunks zeichnen, in deren Nähe schon ein Spieler war. Die Karte deckt sich beim Erkunden auf |
| `maps/*.conf` | `name: "Oberwelt"` usw. | Anzeigename im Kartenmenü |

```bash
chown -R minecraft:minecraft /home/minecraft/paper/plugins/BlueMap
ufw allow 8100/tcp
```

Ingame als OP `/bluemap reload`, Fortschritt mit `/bluemap`. Die Karte liegt unter `http://<Server-IP>:8100` — für Spieler von außen im Router zusätzlich **TCP** 8100 freigeben, dann `http://DEINE-DOMAIN:8100`.

> **Warum `min-inhabited-time`?** Mit dem Standardwert `0` zeichnet BlueMap jeden **erzeugten** Chunk. Nach dem Vorgenerieren mit Chunky ([Schritt 18](#schritt-18--welt-mit-chunky-vorgenerieren)) wäre das die komplette Umgebung mit allen Dörfern, Tempeln und Biomen — praktisch eine Seed-Map. Mit `1` zählt nur, wo wirklich jemand war.
>
> Spielerpositionen zeigt die Karte live, Spieler im Zuschauermodus, unsichtbare und „vanished" Spieler blendet sie aus (`plugin.conf`). Wer gar keine Positionen will: `live-player-markers: false`.

### Weitere Plugins bei Bedarf

- **TAB** — Tabliste und Namensschilder gestalten (rein kosmetisch).
- **Prism** — Alternative oder Ergänzung zu CoreProtect, falls dessen Rollback-Möglichkeiten einmal nicht reichen.

---

## Weitere Empfehlungen

1. **Nur zu Hause – DDNS für Freunde von außerhalb** (DuckDNS, FRITZ!Box MyFRITZ!), falls sich die öffentliche IP ändert.
2. **Nur zu Hause – CGNAT/DS-Lite prüfen**, falls Port-Forwarding gar nicht ankommt: öffentliche IP mit der WAN-IP des Routers vergleichen; `100.64.x.x` = CGNAT. Lösung: echte IPv4 beim Provider anfragen, IPv6 nutzen, oder Tailscale/ZeroTier.
3. **Proxmox-Snapshot als zweite Sicherheitsleine** vor größeren Eingriffen: `pct snapshot <CTID> vor-update`, im Notfall `pct rollback <CTID> vor-update`. Zusätzlich einen wöchentlichen `vzdump` einrichten. Auf dem VServer: Snapshots im Kundenmenü bzw. die Backup-Option des Anbieters.
4. **Off-Site-Backup:** Die Backups liegen sonst nur im selben LXC. Per `rsync`/`rclone` nachts aufs NAS oder in die Cloud kopieren. Auf dem VServer besonders wichtig — fällt er aus oder wird gekündigt, sind die Backups mit weg. Am einfachsten holt ein Rechner oder NAS zu Hause sie nachts ab, dann braucht der VServer keine Zugangsdaten für dein Heimnetz: `rsync -a root@DEINE-SERVER-IP:/home/minecraft/backups/ /pfad/zu/minecraft-backups/`
5. **RAM und CPU sparen:** `view-distance` und `simulation-distance` in `server.properties` reduzieren (z.B. 8 und 6) und `-Xmx` im Service zum RAM passend setzen.
6. **Konsolen-Clients (Xbox/PlayStation/Switch)** können keine eigene Server-Adresse eintragen — nur Handy, Tablet und Windows. Vorher einplanen, falls die Familie auf Konsole spielt.
7. **Zwei Server hinter einer öffentlichen IP:** Der Router kann jeden Port nur an **ein** Gerät weiterleiten. Entweder bekommt nur ein Server die Standardports (25565, 19132) und der andere ist nur im Heimnetz erreichbar — oder der zweite bekommt eigene Ports (z.B. `server-port=25566` und in Geyser `bedrock.port: 19133`, Freigaben entsprechend). Java-Spieler kommen dann per `domain:25566` rein oder ohne Portangabe über eine eigene Subdomain mit **SRV-Eintrag** (`_minecraft._tcp.sub.domain` → Port 25566). Bedrock kennt keine SRV-Einträge, dort muss der Port immer eingegeben werden.

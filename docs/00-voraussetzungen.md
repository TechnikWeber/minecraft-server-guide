# Voraussetzungen (beide Wege, beide Distros)

## Proxmox-LXC-Sizing

| | Bedrock-only | Crossplay (mit vollem Plugin-Stack) |
|---|---|---|
| RAM | mind. 1 GB, empfohlen 2 GB | mind. 6 GB, empfohlen 8 GB |
| Disk | mind. 2 GB, empfohlen 4 GB | mind. 12 GB (CoreProtect-DB wächst) |
| CPU | 1 Kern reicht | mind. 2 Kerne, empfohlen 4 |

> **Warum braucht Crossplay so viel mehr?** Paper + Geyser + Floodgate + ViaVersion + LuckPerms/Vault/EssentialsX/CoreProtect/GriefPrevention/Chunky laufen alle in **einer** JVM. Das ist deutlich mehr als der nackte Bedrock-Server, der ohne JVM läuft.

Weitere Proxmox-Einstellungen (beide Wege):
- **„Start at boot"** aktivieren (automatischer Neustart nach Stromausfall)
- `features: nesting=1` ist bei aktuellen Templates meist schon voreingestellt

## Welche Distro?

| | Ubuntu 24.04 LTS („Noble") | Debian 13 („Trixie") |
|---|---|---|
| Support | regulär bis April 2029, mit kostenlosem Ubuntu Pro deutlich länger | Debian-typisch ca. 5 Jahre |
| Mojang-Support (Bedrock) | offiziell getestete Plattform (Bedrock verlangt Ubuntu 22.04+) | läuft ebenfalls, keine offizielle Mojang-Aussage |
| root-Zugriff im LXC | Standard-Ubuntu-Server braucht `sudo -i`, im Proxmox-LXC ist man i.d.R. schon root | im Proxmox-LXC standardmäßig root |

Beide funktionieren gut — diese Anleitung geht **von root im LXC** aus. Auf einem klassischen Ubuntu-Server-Setup außerhalb eines LXC zuerst `sudo -i`.

## Schritt 0 – Uhrzeit & Zeitzone prüfen (identisch auf beiden Distros)

Falsche Zeitzone → Backups/Updates laufen zur falschen Zeit, Logs haben falsche Zeitstempel.

```bash
timedatectl
timedatectl set-timezone Europe/Berlin
```

Falls `System clock synchronized: no`:

```bash
apt install -y systemd-timesyncd
timedatectl set-ntp true
```

## Schritt 1 – System aktualisieren & Basis-Pakete

```bash
apt update && apt upgrade -y
```

| Paket | Wofür | Ubuntu 24.04 | Debian 13 |
|---|---|---|---|
| `curl`, `wget`, `unzip`, `screen`, `ufw`, `jq`, `file`, `logrotate` | Downloads, Firewall, JSON-Auswertung für Auto-Update, JAR-Prüfung, Log-Rotation | `apt install -y curl wget unzip screen ufw jq file logrotate` | identisch |
| `ca-certificates`, `gnupg` | für das Adoptium-Java-Repo (nur Crossplay) | `apt install -y ca-certificates gnupg` | identisch |
| Bedrock-Laufzeit-Libs | vom Bedrock-Server benötigt | `apt install -y libcurl4t64 libssl3t64` | `apt install -y libcurl4 libssl3` |

> **Warum unterschiedliche Namen bei den Laufzeit-Libs?** Ubuntu 24.04 hat im Zuge der 64-Bit-`time_t`-Umstellung einige Bibliotheken umbenannt (`libcurl4t64`, `libssl3t64`). Debian nutzt weiterhin die klassischen Namen (`libcurl4`, `libssl3`). Meldet `apt` „Paket nicht gefunden", einfach die Variante ohne `t64` probieren — das kann sich mit neueren Ubuntu-Punktversionen wieder ändern.

## Schritt 2 – Dieses Repo auf den Server holen

Scripts, systemd-Units und Config-Vorlagen kommen direkt aus diesem Repo. Alle Anleitungen gehen davon aus, dass es unter `/opt/minecraft-server-guide` liegt:

```bash
apt install -y git
git clone https://github.com/TechnikWeber/minecraft-server-guide.git /opt/minecraft-server-guide
```

> **Später aktualisieren:** `cd /opt/minecraft-server-guide && git pull`, danach die `install`-Zeilen aus [Bedrock Schritt 6](01-bedrock/) bzw. [Crossplay Schritt 11](02-crossplay/) erneut ausführen — erst dann landen neue Script-Versionen in `/usr/local/bin`.

## Java installieren (nur für Crossplay nötig)

Paper 26.1.2 braucht **Java 25** (Pflicht ab Minecraft 26.1). Weder Ubuntu 24.04 noch Debian 13 haben das im Standard-Repository — daher über das Adoptium-Repository (Eclipse Temurin). Der folgende Block ist **auf beiden Distros identisch**, weil er den Codename automatisch ausliest:

```bash
wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | \
  gpg --dearmor -o /usr/share/keyrings/adoptium.gpg

echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | \
  tee /etc/apt/sources.list.d/adoptium.list

apt update
apt install -y temurin-25-jre
java -version
```

Ausgabe sollte `openjdk version "25"` zeigen.

## Benutzer anlegen (beide Wege, beide Distros identisch)

Der Server läuft nie als root, sondern unter einem eigenen Systembenutzer:

```bash
useradd -m -r -s /bin/bash minecraft
```

> **Info:** `-r` macht daraus einen System-User ohne Passwort. Einloggen geht nur **von root aus** mit `su - minecraft`.

## Weiter geht's

- Nur Bedrock: **[docs/01-bedrock](01-bedrock/)**
- Java+Bedrock-Crossplay mit Plugins: **[docs/02-crossplay](02-crossplay/)**

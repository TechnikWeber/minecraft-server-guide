# Wartung, Troubleshooting & manuelle Aufgaben

## Server starten/stoppen/Status

```bash
systemctl start|stop|restart|status minecraft-bedrock   # bzw. minecraft-paper
journalctl -u minecraft-bedrock -n 50                    # letzte 50 Log-Einträge
journalctl -u minecraft-bedrock -f --no-pager             # Live-Logs, Ctrl+C zum Beenden
```

## Automatik manuell anstoßen

| Befehl | Wirkung |
|---|---|
| `/usr/local/bin/mc-bedrock-update.sh` bzw. `mc-crossplay-update.sh` | Update sofort prüfen/durchführen |
| `/usr/local/bin/mc-bedrock-watchdog.sh` bzw. `mc-crossplay-watchdog.sh` | Überwachung sofort ausführen |
| `/usr/local/bin/mc-bedrock-backup.sh` bzw. `mc-crossplay-backup.sh` | Backup sofort erstellen |
| `/usr/local/bin/mc-os-update.sh` | OS-Sicherheitsupdates sofort ausführen |

## OP-Rechte vergeben

**Bedrock** — über die interaktive Konsole (Befehle **ohne** `/`):

```bash
systemctl stop minecraft-bedrock
su - minecraft
cd ~/bedrock
LD_LIBRARY_PATH=. ./bedrock_server
```

Nach `Server started.`: `op DeinXboxGamertag`, dann `stop`, `exit`, `systemctl start minecraft-bedrock`.

Alternativ direkt in `permissions.json` (XUID über `xboxgamertag.com` oder aus `valid_known_packs.json` nach erstem Join):

```json
[{ "permission": "operator", "xuid": "1234567890123456" }]
```

**Crossplay/Java** — genauso über die interaktive Konsole (Befehle **mit** `/` sind ingame, **ohne** `/` in der Konsole):

```bash
systemctl stop minecraft-paper
su - minecraft
cd ~/paper
java -Xms2G -Xmx4G -jar paper.jar --nogui
```

Nach `Done (...)`: `op DeinName`, dann `stop`, `exit`, `systemctl start minecraft-paper`.

> **Ohne Floodgate-Account-Linking** sind Java- und Bedrock-Account zwei verschiedene Spieler — beide einzeln opsen: `op MaxPower3309` und `op .MaxPower3309`. Beide müssen den Server vorher mindestens einmal betreten haben.

## Welt zurücksetzen / neu würfeln

**Immer zuerst ein Backup**, dann ist nichts unwiederbringlich weg: `/usr/local/bin/mc-bedrock-backup.sh` bzw. `mc-crossplay-backup.sh`.

**Variante A – komplett neue Welt, alte löschen** (Bedrock):

```bash
systemctl stop minecraft-bedrock
rm -rf /home/minecraft/bedrock/worlds/"Bedrock level"   # Weltname anpassen!
systemctl start minecraft-bedrock
```

Crossplay (Weltname = `level-name` in `server.properties`, Standard `world`):

```bash
systemctl stop minecraft-paper
cd /home/minecraft/paper
rm -rf world world_nether world_the_end
systemctl start minecraft-paper
```

**Variante B – neue Welt, alte behalten:** einfach `level-name` in `server.properties` auf einen neuen Namen ändern und neu starten. Die alte Welt bleibt unter ihrem alten Ordnernamen erhalten und lässt sich durch Zurücksetzen des Namens jederzeit reaktivieren.

**Bestimmten Seed statt Zufall:** vor dem (Neu-)Start `level-seed=<Wert>` setzen.

> **Wichtig beim Würfeln:** Setz vorher das Wartungs-Flag (`touch /run/minecraft-bedrock.maintenance` bzw. `/run/minecraft-paper.maintenance`), sonst startet der Watchdog den Server während der Löschpausen selbst neu und schickt Fehlalarme. Danach wieder entfernen (`rm -f ...`). Das Flag gilt nur 60 Minuten — bei längeren Sessions zwischendurch erneut `touch`.

## Gamerules (Standard-Übersicht)

Volle Tabelle mit den kindgerechten Empfehlungen: [docs/03-sicherheit-und-kinder/kinderserver-profil.md](../03-sicherheit-und-kinder/kinderserver-profil.md#empfohlene-gamerules-ingame-als-op-einmalig--werden-in-der-welt-gespeichert-überstehen-neustartsupdates). Gamerules werden **in der Welt** gespeichert (nicht in `server.properties`), überstehen also Neustarts/Updates und sind automatisch im Backup enthalten — nur einmal pro Welt setzen.

## Was die Automatik NICHT abdeckt (manuell, betrifft dich selten)

| Aufgabe | Wie oft | Was tun |
|---|---|---|
| **Distro-LTS-Wechsel** (z.B. Ubuntu 24.04→26.04, oder Debian 13→14) | alle 2–3 Jahre | Bewusst und mit Proxmox-Snapshot vorher (`pct snapshot <CTID> vor-upgrade`); bei Ubuntu über `do-release-upgrade`, bei Debian klassisch über die `sources.list` auf den neuen Codenamen. |
| **Proxmox-Host-Updates** | gelegentlich | Laufen auf dem Host, nicht im LXC. |
| **Kernel** | – | Im LXC gibt es keinen eigenen Kernel (kommt vom Host) — keine Kernel-Updates nötig. |
| **Paper-Major-Sprung** (z.B. 1.21.11 → 1.21.12/26.x) | wenn Geyser nachzieht | 1) Prüfen, ob Geyser die Zielversion schon unterstützt (Geyser-Discord/GitHub). 2) `PAPER_MC_VERSION` in `/etc/minecraft-guide.conf` anpassen. 3) `/usr/local/bin/mc-crossplay-update.sh` laufen lassen (holt den neuesten Build der neuen Version, mit Backup+Rollback). |
| **ViaVersion/ViaBackwards** | gelegentlich | Aktuelle Version auf [hangar.papermc.io/ViaVersion/ViaVersion/versions](https://hangar.papermc.io/ViaVersion/ViaVersion/versions), Links in Crossplay-Anleitung Schritt 3 ersetzen. |
| **LuckPerms/EssentialsX/CoreProtect/GriefPrevention/Chunky** | gelegentlich | Neue JAR von der jeweiligen Quelle ([plugins-und-befehle.md](../02-crossplay/plugins-und-befehle.md)) herunterladen, Server neu starten. |
| **Ubuntu Pro / Debian ESM** | ab Support-Ende | Kostenlos für Privatnutzung aktivierbar, verlängert Sicherheitsupdates um Jahre. |

**Faustregel:** Im Alltag musst du nichts tun. Aufmerksam werden solltest du nur, wenn eine **ntfy-Meldung** kommt — die Nachricht sagt jeweils, was zu prüfen ist.

## ntfy-Meldungen — was sie bedeuten

| Titel | Bedeutung | Handlungsbedarf |
|---|---|---|
| `Update erfolgreich` | Aktualisiert, Server läuft. | Nein |
| `Update fehlgeschlagen (Rollback)` | Update kaputt → alter Stand automatisch wiederhergestellt, Server läuft. | Bei Gelegenheit Logs prüfen |
| `KRITISCH - Server unten` / `manueller Eingriff nötig` | Auch der Rollback startet nicht. | **Ja, sofort** — Befehle stehen in der Nachricht |
| `Server DOWN` | Watchdog: Server weg, Auto-Neustart hat nicht geholfen. | **Ja** — Befehle stehen in der Nachricht |
| `automatisch neu gestartet` | War kurz weg, Watchdog hat's gefixt. | Nein, im Auge behalten falls häufig |
| `wieder online` | Nach Ausfall wieder erreichbar. | Nein |
| `Backup-Problem` | Backup evtl. nicht sauber erstellt. | `ls -lh /home/minecraft/backups` prüfen |
| `Sicherheitsupdates installiert` | apt-Security-Updates eingespielt. | Nur falls „Neustart empfohlen" dabei steht |
| `Neustart empfohlen` | Kernel/Lib aktualisiert. | Bei Gelegenheit `reboot` |

## ntfy absichern

Ein öffentliches `ntfy.sh`-Topic kann von **jedem** gelesen und beschrieben werden, der den Namen kennt. Absicherungsstufen:

1. **Zufälliger Topic-Name** (Minimum, in den Config-Vorlagen schon so vorgesehen, z.B. `dein-server-a8f3k2q7`).
2. **Access-Token**: `curl -H "Authorization: Bearer tk_..." ...` in `mc_notify()` ergänzen (`scripts/common/mc-common.sh`).
3. **Eigener ntfy-Server** selbst hosten, statt `ntfy.sh` zu nutzen.

## Feste IP, DDNS, CGNAT

Siehe [docs/01-bedrock „Weitere Empfehlungen"](../01-bedrock/#weitere-empfehlungen) — gilt für beide Wege gleich.

## Troubleshooting

| Problem | Lösung |
|---|---|
| `Port may be in use` beim Bedrock-Start | `pkill -f bedrock_server`, dann erneut starten |
| Geyser stürzt mit `ExceptionInInitializerError` ab | Paper-Version zu neu für Geyser — auf die gepinnte Version zurück, bis Geyser nachzieht |
| Bedrock-Spieler werden beim Chatten gekickt | `enforce-secure-profile=false` in `server.properties` prüfen |
| `apt`-Befehl meldet „could not get lock" | `unattended-upgrades` läuft parallel — kurz warten und erneut versuchen, oder deaktivieren: `systemctl disable --now unattended-upgrades` |
| `journalctl`-Zeile endet mit `>` | Nur abgeschnitten (Pager) — `q` zum Verlassen, oder `--no-pager` anhängen |
| Downloadete Plugin-Datei ist nur wenige KB groß | War eine Fehlerseite statt der JAR — `file datei.jar` prüfen, Link neu kopieren |

# 🎮 Minecraft-Server-Guide

Ein Monorepo, das zeigt, wie man einen **Minecraft Bedrock**- oder einen **Bedrock+Java-Crossplay**-Server auf **Debian** oder **Ubuntu** aufbaut — mit Fokus auf den konkreten Standardfall: **Proxmox LXC**. Automatische Updates mit Rollback, tägliche Backups, ntfy-Benachrichtigungen, ein sinnvoller Plugin-Stack und ein durchdachtes Sicherheitskonzept sind von Anfang an eingeplant, nicht nachträglich angeflanscht.

Dieses Repo ersetzt drei ältere Einzel-Anleitungen (`ubuntu-minecraft-server`, `ubuntu-minecraft-crossplay`, `debian-minecraft-crossplay-server`) und führt ihre besten Ideen zusammen.

## Welchen Weg nehmen?

| Frage | Antwort | Weg |
|---|---|---|
| Nur Handy/Tablet/Konsole/Win10+, keine Plugins nötig? | Ja | **[Bedrock-only](docs/01-bedrock/)** — leichtgewichtig, wenig RAM |
| Java-PC-Spieler UND Bedrock-Spieler zusammen auf einer Welt, plus Rechte/Schutz/Komfort-Plugins? | Ja | **[Crossplay (Paper + Geyser + Plugins)](docs/02-crossplay/)** — mehr RAM, mehr Möglichkeiten |

Debian- und Ubuntu-Unterschiede werden **nur dort** erklärt, wo sie wirklich existieren (Paketnamen, Adoptium-Codename, `unattended-upgrades`-Details) — der Rest ist identisch.

## Struktur dieses Repos

```
docs/
  00-voraussetzungen.md          Proxmox-LXC-Sizing, Zeitzone, Basis-Pakete, Repo klonen (beide Wege, beide Distros)
  01-bedrock/                    Kompletter Bedrock-only-Weg
  02-crossplay/                  Kompletter Crossplay-Weg (Paper/Geyser/Floodgate/Plugins)
  03-sicherheit-und-kinder/      Sicherheits-Stufen (Whitelist/Gamemode/Claims) + konkretes Kinderserver-Profil
  04-spieler-anleitung/          Fertige Spieler-Anleitung zum Weitergeben (auch als Discord-Copy-Paste-Version)
  05-erweiterungen/              Optionale Ausbaustufen: Economy, Discord-Bridge, WorldGuard, mehr Welten
  06-wartung/                    Alltägliche Befehle, OP vergeben, Welt zurücksetzen, Troubleshooting
scripts/
  common/mc-common.sh            Gemeinsame Funktionen (ntfy, Health-Check, Wartungs-Flag) — von allen anderen Scripts gesourct
  bedrock/                       Backup/Update(+Rollback)/Watchdog für den Bedrock-Weg
  crossplay/                     Backup/Update(+Rollback)/Watchdog für den Crossplay-Weg
  os/mc-os-update.sh             OS-Sicherheitsupdates (apt), für beide Wege gleich
systemd/                         Service-Unit-Vorlagen
config/                          Beispiel-Konfigurationsdateien zum Kopieren nach /etc/minecraft-guide.conf
```

Jede Anleitung verweist auf die konkrete Datei unter `scripts/`, `systemd/` oder `config/`, die dabei zum Einsatz kommt — Copy-Paste-Codeblöcke gibt es nur noch für Dinge, die wirklich einmalig sind (Config-Werte, einzelne Befehle).

## Schnellstart für einen Kinderserver

Ihr wollt direkt den kindgerechten Weg? → **[docs/03-sicherheit-und-kinder/kinderserver-profil.md](docs/03-sicherheit-und-kinder/kinderserver-profil.md)** — peaceful, Adventure-Standard mit Freischaltung durch OP, CoreProtect als Netz, GriefPrevention-Claims (inkl. geschütztem Spawn), Chunky-Vorgenerierung.

## Stand & Versionen

Diese Anleitung ist an konkreten Versionen (Paper, Geyser, Plugins, Java) orientiert, weil **Geyser und die Plugins der limitierende Faktor** sind — nie blind auf die neueste Paper-Version springen, bevor Geyser und alle Plugins sie unterstützen. Aktuell: **Paper 26.1.2 mit Java 25** (Stand September 2026). Details dazu in [docs/02-crossplay](docs/02-crossplay/).

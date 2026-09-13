# 🎮 Minecraft-Server-Guide

Zwei komplette Anleitungen für einen eigenen Minecraft-Server auf **Debian** oder **Ubuntu** — mit Fokus auf den Standardfall **Proxmox LXC**. Automatische Updates mit Rollback, tägliche Backups, Überwachung mit ntfy-Benachrichtigungen und ein durchdachtes Sicherheitskonzept bis hin zum Kinderserver sind von Anfang an eingeplant, nicht nachträglich angeflanscht.

Dieses Repo ersetzt drei ältere Einzel-Anleitungen (`ubuntu-minecraft-server`, `ubuntu-minecraft-crossplay`, `debian-minecraft-crossplay-server`) und führt ihre besten Ideen zusammen.

## Welchen Weg nehmen?

| | **A – Bedrock** | **B – Crossplay** |
|---|---|---|
| Wer spielt? | Handy, Tablet, Windows-PC (Bedrock Edition) | dieselben **plus** Java Edition am PC |
| Plugins (`/home`, `/tpa`, Grundstücksschutz, Schäden zurückrollen) | – | ✅ |
| RAM im LXC | 2 GB | 8 GB |
| Aufwand | gering | mittel |
| Kinderserver | Adventure-Standard mit Freischaltung, Gamerules | zusätzlich Grundstücksschutz, CoreProtect, Starter-Kit und Spieler-Anleitung zum Weitergeben |

### → [A – Bedrock-Anleitung](docs/a-bedrock/) · [B – Crossplay-Anleitung](docs/b-crossplay/)

Jede Anleitung ist **komplett** — von der leeren LXC bis zu Wartung und Troubleshooting, ohne zwischen Dateien springen zu müssen. Was für beide Wege gilt, steht bewusst in beiden.

## Struktur dieses Repos

```
docs/
  a-bedrock/README.md                        A – komplette Bedrock-Anleitung
  b-crossplay/README.md                      B – komplette Crossplay-Anleitung
  b-crossplay/spieler-anleitung.md           Anleitung zum Weitergeben an die Spieler
  b-crossplay/spieler-anleitung-discord.md   dieselbe als Discord-Nachrichten
scripts/
  common/mc-common.sh                        Gemeinsame Funktionen (ntfy, Health-Check, Wartungs-Flag)
  bedrock/                                   Backup, Update mit Rollback, Watchdog für A
  crossplay/                                 Backup, Update mit Rollback, Watchdog für B
  os/mc-os-update.sh                         OS-Sicherheitsupdates, für beide Wege gleich
systemd/                                     Service-Units
config/                                      Config-Vorlagen und logrotate
```

Die Anleitungen holen Scripts, Units und Vorlagen direkt aus diesem Repo — geklont nach `/opt/minecraft-server-guide`.

## Stand & Versionen

Stand September 2026:

- **A – Bedrock:** Bedrock Dedicated Server 1.26.x, hält sich per Auto-Update selbst aktuell.
- **B – Crossplay:** Paper 26.1.2 mit Java 25, Geyser und Floodgate, alle Plugin-Versionen geprüft. Hier sind **Geyser und die Plugins der limitierende Faktor** — nie blind auf die neueste Paper-Version springen, bevor Geyser und alle Plugins sie unterstützen.

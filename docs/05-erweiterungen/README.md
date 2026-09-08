# Erweiterungen (optional, perspektivisch)

Bewusst nicht Teil des Standard-Setups — damit der Server nicht überfrachtet startet. Hier als Ideen für später, mit dem jeweils einfachsten sinnvollen Einstieg.

## Einfaches Economy-System

Der einfachste Einstieg nutzt, was schon installiert ist: **EssentialsX-Economy über Vault** — kein zusätzliches Plugin nötig.

1. In `plugins/Essentials/config.yml`: Startguthaben setzen (`starting-balance:`).
2. Grundbefehle stehen den Spielern automatisch zur Verfügung: `/balance`, `/pay <Spieler> <Betrag>`.
3. Als Admin Guthaben vergeben: `/eco give <Spieler> <Betrag>` (z.B. als Belohnung).

Reicht das später nicht mehr (echte Shops mit Preisliste, Spieler verkaufen sich gegenseitig Items)? Dann als nächster Schritt ein dediziertes Shop-Plugin wie **ShopGUIPlus** (GUI-Menü-Shop) oder **ChestShop** (Spieler richten eigene Verkaufskisten ein) — beide bauen auf Vault auf und lesen dieselbe Economy.

## WorldEdit + WorldGuard (feinere Regionen)

Der Standard-Claim-Schutz läuft nur über GriefPrevention (siehe [Sicherheits-Stufen](../03-sicherheit-und-kinder/)). Reicht das nicht mehr — z.B. weil ihr in einer Region gezielt PvP an/aus schalten wollt, unabhängig von Claims, oder komplexe Terrain-Bearbeitung braucht (Bereiche kopieren/füllen, Schematics) — dann:

- **WorldEdit** zuerst installieren (Terrain-Werkzeug: `//wand`, `//set`, `//copy`/`//paste`).
- **WorldGuard** danach (braucht WorldEdit als Abhängigkeit!): eigene Regionen mit Flags definieren, z.B. `/rg define spawn`, dann Flags wie `pvp deny` setzen.
- Beide laufen problemlos **parallel** zu GriefPrevention: WorldGuard für admin-definierte Bereiche mit Regeln, GriefPrevention für die Claims der Spieler untereinander.

Download: [hangar.papermc.io/EngineHub/WorldEdit](https://hangar.papermc.io/EngineHub/WorldEdit/versions), WorldGuard über [modrinth.com/plugin/worldguard](https://modrinth.com/plugin/worldguard/versions) (nicht auf Hangar verfügbar).

## Discord-Anbindung

**DiscordSRV** verbindet den Minecraft-Chat mit einem Discord-Channel (beide Richtungen), plus Join/Leave-Meldungen. Passt gut zusammen mit der [Discord-Copy-Paste-Version der Spieler-Anleitung](../04-spieler-anleitung/discord-format.md), die ihr schon vorbereitet habt. Einrichtung: Bot in Discord-Developer-Portal anlegen, Token in `plugins/DiscordSRV/config.yml` eintragen.

## Mehrere Welten

**Multiverse-Core** erlaubt mehrere parallele Welten auf demselben Server — z.B. eine Survival- und eine separate Creative-Bauwelt, oder eine eigene Welt pro Kind. `/mv create <name> normal` legt eine neue Welt an, `/mv tp <name>` wechselt hinein. Chunky (Schritt 10 der Crossplay-Anleitung) lässt sich pro Welt einzeln anwenden.

## Weitere gängige QoL-Plugins (nur bei Bedarf)

- **TAB** — Tabliste/Nametags hübscher gestalten (rein kosmetisch).
- **Prism** — Alternative/Ergänzung zu CoreProtect mit etwas anderem Funktionsumfang, falls dessen Rollback-Optionen mal nicht reichen.

> Grundsatz: lieber ein Plugin zu wenig als zu viel installieren — jedes zusätzliche Plugin ist eine weitere Versions-Abhängigkeit beim nächsten Paper-Update (siehe [docs/06-wartung](../06-wartung/)).

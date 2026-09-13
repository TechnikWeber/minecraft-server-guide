# Kinderserver-Profil (konkret)

Das ist das für euren Fall empfohlene Profil — peaceful, Adventure-Standard mit Freischaltung durch OP, GriefPrevention-Claims inkl. geschütztem Spawn, CoreProtect als Netz. Setzt auf dem [Crossplay-Weg](../02-crossplay/) auf (Bedrock-only hat kein Claim-System, siehe unten für die abgespeckte Variante).

## server.properties

| Einstellung | Wert | Warum |
|---|---|---|
| `gamemode` | `adventure` | Niemand kann versehentlich (oder absichtlich) bauen/abbauen, bevor du es erlaubst |
| `difficulty` | `peaceful` | Keine Monster, kein Hunger — kein Frust, kein Angriffsrisiko |
| `force-gamemode` | `false` | Freigeschaltete Kinder **bleiben** im Creative/Survival-Modus, auch nach Reconnect |
| `allow-cheats` | `true` (Bedrock) | Nötig, damit du als OP `/gamemode` etc. nutzen kannst |
| `online-mode` | `true` | Xbox/Microsoft-Auth — nicht abschalten |

Hintergrund & Alternativen (Spectator statt Adventure, Whitelist): **[Sicherheits-Stufen](README.md)**.

## Freischaltung durch OP

Ein Kind darf jetzt bauen: als OP (Konsole ohne `/` bei Bedrock, ingame mit `/` bei Crossplay):

```
gamemode creative NameDesKindes
```

Wieder zurück auf „nur anschauen": `gamemode adventure NameDesKindes`. Wer lieber das „echte" Überleben mag statt Creative: `gamemode survival NameDesKindes` + Gamerule „Items bleiben beim Tod erhalten“ (siehe unten), damit ein seltener Tod nicht alle Sachen kostet.

## Schutz (nur Crossplay-Weg — GriefPrevention)

1. **Spawn dauerhaft schützen** (einmalig, als OP): `/adminclaims` → mit goldener Schaufel zwei Ecken um den Spawn-Bereich anklicken → `/basicclaims`. Details: [plugins-und-befehle.md](../02-crossplay/plugins-und-befehle.md#griefprevention--claims).
2. **Kinder claimen ihr eigenes Grundstück selbst** per goldener Schaufel — genau das steht in der [Spieler-Anleitung](../04-spieler-anleitung/), die du den Kindern gibst.
3. **CoreProtect als Netz**: Falls doch mal etwas kaputt geht, `/co rollback u:Name t:1h r:20` macht es rückgängig — zusätzlich zu den ohnehin laufenden täglichen Backups.

Bedrock-only hat kein Plugin-System, also keine Claims — dort trägt allein die Adventure-Standard+Freischaltung-Kombination die ganze Last des Schutzes. Für Grundstücksschutz zwischen Kindern lohnt sich der Umstieg auf Crossplay.

## Empfohlene Gamerules (ingame als OP, einmalig — werden in der Welt gespeichert, überstehen Neustarts/Updates)

`difficulty=peaceful` verhindert schon Monster und Hunger. Optional zusätzlich, für noch mehr Ruhe:

| Wirkung | Crossplay / Java (ab 1.21.11) | Bedrock |
|---|---|---|
| Immer Tag | `/gamerule advance_time false` + `/time set day` | `/gamerule dodaylightcycle false` + `/time set day` |
| Immer klares Wetter | `/gamerule advance_weather false` + `/weather clear` | `/gamerule doweathercycle false` + `/weather clear` |
| Keine Tiere/Monster spawnen | `/gamerule spawn_mobs false` | `/gamerule domobspawning false` |
| Mobs verändern keine Blöcke | `/gamerule mob_griefing false` | `/gamerule mobgriefing false` |
| Kinder können sich nicht gegenseitig verletzen | `/gamerule pvp false` | `/gamerule pvp false` |
| Kein Fall-/Feuerschaden | `/gamerule fall_damage false` · `/gamerule fire_damage false` | `/gamerule falldamage false` · `/gamerule firedamage false` |
| TNT explodiert nicht | `/gamerule tnt_explodes false` | `/gamerule tntexplodes false` |
| Items bleiben beim Tod erhalten (nur relevant in Survival) | `/gamerule keep_inventory true` | `/gamerule keepinventory true` |
| Koordinaten anzeigen — hilft Kindern bei der Orientierung | – (Java-Spieler sehen sie mit F3) | `/gamerule showcoordinates true` |

> **Java hat die Gamerules mit 1.21.11 umbenannt** (snake_case statt camelCase, z.B. `doDaylightCycle` → `advance_time`). Die alten Namen funktionieren auf Paper 26.1.2 nicht mehr. Im Zweifel `/gamerule ` tippen und die Tab-Vervollständigung zeigt die gültigen Namen.

## Chunky (Crossplay-Weg)

Vorab generieren, damit Erkunden nicht laggt — gerade Kinder wechseln oft schnell den Ort. Siehe [Crossplay-Anleitung, Schritt 10](../02-crossplay/README.md#schritt-10--welt-mit-chunky-vorgenerieren-standard).

## Starter-Kit (Crossplay-Weg, EssentialsX)

Die [Spieler-Anleitung](../04-spieler-anleitung/) verweist auf `/kit schaufel` für eine neue goldene Schaufel. Dafür in `plugins/Essentials/kits.yml` einen Kit definieren:

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

> Das genaue `kits.yml`-Format kann sich je EssentialsX-Version leicht ändern — nach dem ersten Speichern immer `/kit schaufel` testen und ggf. mit der aktuellen [EssentialsX-Doku](https://essentialsx.net/wiki/Kits.html) abgleichen. Automatisches Startpaket beim ersten Join: `EssentialsXSpawn` kann ein Kit an `firstspawn` koppeln, oder man vergibt es einmalig per `/kit start Name`.

## Backups

Laufen für den Kinderserver genauso wie im Standardfall automatisch — nichts Extra einzustellen, siehe [docs/02-crossplay](../02-crossplay/#schritt-11--ntfy-zentrale-config-backupupdatewatchdog-os-updates).

Weiter: **[Spieler-Anleitung zum Weitergeben](../04-spieler-anleitung/)**

# Plugin-Referenz & Befehle

Alle hier genannten Plugins sind **serverseitig** — sie funktionieren automatisch für Java- **und** Bedrock-Spieler (via Geyser), ohne dass Bedrock-Spieler irgendetwas installieren müssten.

## Reihenfolge & Abhängigkeiten

| Plugin | Zweck | Abhängigkeit |
|---|---|---|
| **LuckPerms** | Rechte-/Gruppenverwaltung | – |
| **Vault** | API-Brücke zwischen Plugins (Economy, Chat-Präfixe) | – |
| **EssentialsX** (+Spawn +Chat) | Basis-Befehle: `/home`, `/tpa`, `/warp`, Kits, optional Economy | Economy/Chat-Präfixe brauchen Vault |
| **CoreProtect** | Block-Logging & Rollback gegen Griefing | – |
| **GriefPrevention** | Spieler-Claims per goldener Schaufel + Admin-Claims (Spawn-Schutz) | – |
| **Chunky** | Welt vorgenerieren (weniger Lag beim Erkunden) | – |

> WorldEdit/WorldGuard sind hier **absichtlich nicht** dabei (siehe [Sicherheits-Stufen](../03-sicherheit-und-kinder/)) — Ausbaustufe dazu in [docs/05-erweiterungen](../05-erweiterungen/).

## Download-Quellen

Plugin-Versionen ändern sich oft — die häufigste Fehlerquelle sind veraltete Direkt-Links. Immer auf der offiziellen Seite die **für 26.1.2 passende Version** wählen. Die in der Hauptanleitung verlinkten Versionen sind geprüft (Stand September 2026):

| Plugin | Quelle |
|---|---|
| LuckPerms | [luckperms.net/download](https://luckperms.net/download) (Variante **Bukkit**) |
| Vault | [github.com/MilkBowl/Vault/releases](https://github.com/MilkBowl/Vault/releases) (`Vault.jar`) — letztes Release 2020; bei Problemen ist [VaultUnlocked](https://modrinth.com/plugin/vaultunlocked) der gepflegte Nachfolger |
| EssentialsX | [essentialsx.net/downloads.html](https://essentialsx.net/downloads.html) — Module `EssentialsX`, `EssentialsXSpawn`, `EssentialsXChat` |
| CoreProtect | [modrinth.com/plugin/coreprotect](https://modrinth.com/plugin/coreprotect/versions) — Version für 26.1.2 |
| GriefPrevention | [github.com/TechFortress/GriefPrevention/releases](https://github.com/TechFortress/GriefPrevention/releases) (`GriefPrevention.jar`) |
| Chunky | [hangar.papermc.io/pop4959/Chunky](https://hangar.papermc.io/pop4959/Chunky) bzw. [modrinth.com/plugin/chunky](https://modrinth.com/plugin/chunky) — Plattform **Paper** |

Downloads immer prüfen: `file ~/paper/plugins/*.jar` muss `Java archive data (JAR)` oder `Zip archive data` zeigen, nicht `ASCII text`/`HTML` (= Fehlerseite).

> **CoreProtect-Hinweis:** Legt beim ersten Start eine SQLite-Datenbank an (`plugins/CoreProtect/`), die mit der Zeit wächst und im Backup enthalten ist. Für einen privaten Server reicht SQLite locker.

## Befehle

Alle Befehle ingame im Chat mit `/`, oder in der Server-Konsole ohne `/`. Bedrock-Spieler tippen sie genauso.

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
| `/gms /gmc /gma /gmsp` | Gamemode Survival/Creative/Adventure/Spectator |

### GriefPrevention – Claims

Details und die kindgerechte Erklärung: **[docs/04-spieler-anleitung](../04-spieler-anleitung/)**.

| Befehl | Wirkung |
|---|---|
| Goldene Schaufel, zwei gegenüberliegende Ecken anklicken | Grundstück claimen |
| `/trust <Spieler>` · `/untrust <Spieler>` | Freund auf eigenem Claim bauen lassen / Recht entziehen |
| `/abandonclaim` | Eigenen Claim aufgeben |
| `/claimslist` | Eigene Claims anzeigen |
| `/adminclaims` | **Als OP**: Schaufel in Admin-Modus schalten — der nächste Claim gehört keinem Spieler, läuft nie ab, kann von Spieler-Claims nicht überschrieben werden. **So schützt du den Spawn dauerhaft.** |
| `/basicclaims` | Schaufel zurück in den normalen (Spieler-)Modus schalten |
| `/ignoreclaims` | **Als OP**: eigene Claim-Grenzen temporär ignorieren (z.B. um im Spawn-Bereich zu bauen) |

**Spawn schützen — Schritt für Schritt:** Einmalig als OP `/adminclaims` eingeben, dann mit der goldenen Schaufel zwei Ecken um den Spawn-Bereich anklicken. Danach `/basicclaims`, um die Schaufel wieder in den normalen Modus zu schalten (sonst würde der nächste eigene Claim ebenfalls ein Admin-Claim werden).

### CoreProtect – Logging & Rollback

| Befehl | Wirkung |
|---|---|
| `/co inspect` (kurz `/co i`) | Inspektor umschalten, dann Block anklicken → wer hat wann was gemacht |
| `/co rollback u:Name t:1h r:20` | Schaden eines Spielers der letzten Stunde im 20-Block-Radius zurückrollen |
| `/co restore u:Name t:1h r:20` | Gegenteil von rollback (falls versehentlich zu viel zurückgerollt wurde) |

### LuckPerms – Rechte

```
lp creategroup builder
lp group builder permission set essentials.kit.schaufel true
lp user MaxPower3309 parent add builder
lp editor
```

`lp editor` gibt einen Web-Link, in dem sich Gruppen/Rechte bequem im Browser bearbeiten lassen. Volle Doku: [luckperms.net/wiki](https://luckperms.net/wiki/Home).

> **Crossplay-Hinweis:** Ohne Floodgate-Account-Linking (Schritt 8 der Hauptanleitung) hängen Rechte am Spielernamen — ohne Linking müssen sie sowohl an `MaxPower3309` als auch an `.MaxPower3309` (Bedrock-Präfix) vergeben werden.

### Chunky – Weltgenerierung

Siehe Schritt 10 der [Crossplay-Hauptanleitung](README.md#schritt-10--welt-mit-chunky-vorgenerieren-standard).

# Sicherheits-Stufen

Drei unabhängige Stufen, die sich beliebig kombinieren lassen — von „wer darf überhaupt rein" bis „was passiert, falls doch mal was schiefgeht". Der Standard in diesem Repo ist bewusst **offen und Survival** (Stufe 1 aus, Stufe 2 = Standard-Gamemode, Stufe 3 optional); für einen Kinderserver empfehlen wir alle drei kombiniert — siehe **[kinderserver-profil.md](kinderserver-profil.md)**.

## Stufe 1 — Zugangskontrolle: Whitelist/Allowlist

Bestimmt, wer den Server überhaupt betreten darf. Standardmäßig **aus** (jeder mit der IP kann joinen).

- **Bedrock:** `allow-list=true` in `server.properties`, Namen in `allowlist.json` eintragen.
- **Java/Crossplay:** `white-list=true` in `server.properties`, `/whitelist add <Name>` ingame, `whitelist.json` verwaltet Paper selbst.

> Sinnvoll, sobald der Server über das Internet erreichbar ist und nicht jeder Fremde reinkommen soll — unabhängig vom Gamemode.

## Stufe 2 — Verhaltenskontrolle: Standard-Gamemode + `force-gamemode`

Bestimmt, was ein frisch verbundener Spieler **kann**, bevor irgendjemand eingreift.

| Gamemode | Kann bauen/abbauen? | Kann Items benutzen/aufheben? | Kann fliegen/durch Wände? |
|---|---|---|---|
| `survival` | ja | ja | nein |
| `creative` | ja, unbegrenzt | ja | ja |
| `adventure` | **nein** | ja (Kisten öffnen, Türen, Hebel) | nein |
| `spectator` | **nein** | **nein, gar keine Interaktion** | ja, durch Wände |

**Adventure vs. Spectator:** Beide verhindern Bauen/Abbauen. Der Unterschied: In **Adventure** kann man sich normal bewegen und Dinge benutzen (Türen öffnen, Kisten durchsuchen, Hebel ziehen) — fühlt sich für Kinder „normal" an. In **Spectator** kann man *gar nichts* anfassen und fliegt geisterhaft durch die Welt — die strengste Stufe, sinnvoll für sehr kleine Kinder oder zum reinen Zuschauen, fühlt sich aber nicht wie „richtig spielen" an. Für die meisten Fälle ist **Adventure** der bessere Standard.

**Das Prinzip „kontrolliertes Bauen":** `gamemode=adventure` (oder `spectator`) als Standard + `force-gamemode=false`. Wer bauen darf, wird **einzeln** hochgestuft:

- Bedrock (Server-Konsole, **ohne** `/`): `gamemode creative DeinName`
- Java/Crossplay (ingame als OP, **mit** `/`): `/gamemode creative DeinName`

> **Warum `force-gamemode=false` entscheidend ist:** `false` (Standard) heißt, ein einmal hochgestufter Spieler **bleibt** in seinem Modus, auch nach Reconnect/Neustart. Steht es auf `true`, wird **jeder** bei **jedem** Join auf den Standard-Modus zurückgesetzt — die individuelle Freischaltung wäre bei jedem Login wieder weg. `true` ist nur sinnvoll, wenn du willst, dass *niemand* dauerhaft im freigeschalteten Modus bleiben soll (z.B. ein reiner Event-Bauserver mit temporärem Creative für alle).

Wer die Baurechte wieder entziehen will: `/gamemode adventure DeinName` (in der Bedrock-Konsole ohne `/`).

## Stufe 3 — Schadensbegrenzung: Claims + CoreProtect

Nur relevant, wenn Spieler in `survival`/`creative` bauen dürfen (Stufe 2 hochgestuft, oder Standard ist ohnehin offen).

- **GriefPrevention** (nur im Crossplay-Weg, Bedrock hat kein Plugin-System): Spieler schützen ihr eigenes Grundstück per goldener Schaufel selbst (`/trust`, `/untrust`, `/abandonclaim`). Details & kindgerechte Erklärung: [docs/04-spieler-anleitung](../04-spieler-anleitung/).
- **Admin-Claim für den Spawn:** Als OP `/adminclaims` → mit der goldenen Schaufel zwei Ecken um den Spawn klicken → `/basicclaims`. Der Spawn ist damit **dauerhaft geschützt**, gehört keinem Spieler, läuft nie ab, kann von niemandem überschrieben werden. Details: [plugins-und-befehle.md](../02-crossplay/plugins-und-befehle.md#griefprevention--claims).
- **CoreProtect** als Sicherheitsnetz: Auch wenn doch mal etwas kaputt geht (Claim vergessen, Exploit, Missverständnis) — `/co rollback u:Name t:1h r:20` macht den Schaden rückgängig, egal welche Stufe vorher aktiv war.
- **Backups** sind unabhängig von allen drei Stufen sowieso immer aktiv (siehe [docs/01-bedrock](../01-bedrock/) bzw. [docs/02-crossplay](../02-crossplay/)) — die letzte Sicherheitsleine.

## Zusammenspiel — drei typische Konfigurationen

| Ziel | Stufe 1 | Stufe 2 | Stufe 3 |
|---|---|---|---|
| **Standard (vanilla survival, offen)** | aus | `survival`, offen für alle | optional |
| **Privater Freundeskreis** | Whitelist an | `survival` oder `creative`, offen für gelistete Spieler | GriefPrevention empfehlenswert |
| **Kinderserver** (siehe [kinderserver-profil.md](kinderserver-profil.md)) | optional | `adventure`-Standard + OP-Freischaltung | GriefPrevention + Admin-Claim Spawn + CoreProtect, alles aktiv |

Weiter: **[Kinderserver-Profil (konkret)](kinderserver-profil.md)** · **[Spieler-Anleitung](../04-spieler-anleitung/)**

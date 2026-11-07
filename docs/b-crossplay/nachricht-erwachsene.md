# Nachricht an die Mitspieler (Erwachsene / Freundeskreis)

> Vorlage zum Kopieren in WhatsApp oder Discord — für einen Server **ohne** den Komfort-Stack (nur Geyser, Floodgate, ViaVersion, optional BlueMap), auf dem neue Spieler im Abenteuermodus starten und die Mitspieler selbst OP sind. Für Kinder und den vollen Plugin-Stack: [spieler-anleitung.md](spieler-anleitung.md).
>
> Vorher ersetzen: `SERVERNAME`, `UNTERTITEL`, `DEINE-DOMAIN`, Bedrock-Port (Standard `19132`), BlueMap-Zeile löschen, falls keine Karte läuft. `*Text*` ist in WhatsApp fett, in Discord kursiv — beides lesbar.

```
🎮 *SERVERNAME* – UNTERTITEL

*So kommt ihr rein*
☕ *Java (PC):* Mehrspieler → Server hinzufügen → Adresse: *DEINE-DOMAIN*
📱 *Bedrock (Handy, Tablet, Windows):* Spielen → Server → Server hinzufügen
   Name: SERVERNAME · Adresse: *DEINE-DOMAIN* · Port: *19132*
Am besten die neueste Version nehmen. Konsolen (Xbox/PS/Switch) gehen nur über einen Umweg – meldet euch dann bei mir.

*Erster Login*
Ihr startet im Abenteuermodus (nur schauen, nichts abbauen). Sagt kurz Bescheid, dann schalte ich euch frei. 🔓

*Java + Bedrock verknüpfen* (nur wenn ihr beides spielt – bitte direkt am Anfang!)
1. Mit Java einloggen, im Chat: */linkaccount BedrockName*
   → ihr bekommt einen Code
2. Mit Bedrock einloggen (ihr heißt dort .BedrockName), im Chat: */linkaccount JavaName CODE*
3. Ihr werdet einmal gekickt – danach seid ihr auf beiden derselbe Spieler (gleiches Inventar, gleiche Rechte).
Bedrock-Namen ohne Verknüpfung haben immer einen Punkt davor, z.B. .Max

🗺️ *Live-Karte:* http://DEINE-DOMAIN:8100
Die Karte zeigt nur, wo schon jemand war – sie deckt sich beim Erkunden auf.

*Spielregeln (Standard-Minecraft)*
• Schwierigkeit: leicht
• Tod = Items fallen (5 Min. Zeit zum Einsammeln)
• Einer schläft = Nacht vorbei 🛏️
• PvP an, Creeper sprengen Blöcke

*Für OPs* 👑
• Spieler freischalten: /gamemode survival Name
• Selbst umschauen: /gamemode spectator (danach wieder /gamemode survival)
• Zu jemandem: /tp Name · jemanden holen: /tp Name DeinName
• Tag/Wetter: /time set day · /weather clear
• Störenfried: /kick Name · /ban Name
⚠️ Mit OP-Rechten lässt sich alles kaputt machen – bitte nichts an Gamerules oder am Spawn ändern, ohne zu fragen. Rückgängig geht nur über das nächtliche Backup.
```

**Reihenfolge beim Freischalten:** Wer Java und Bedrock spielt, verknüpft zuerst — danach reicht **ein** `/op JavaName` für beide Geräte. Nur-Bedrock-Spieler müssen einmal auf dem Server gewesen sein, dann `/op .Gamertag`.

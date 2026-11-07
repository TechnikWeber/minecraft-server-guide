"use strict";
// Cockpit-Seite "Minecraft". Muss als eigene Datei vorliegen: Cockpits
// Content-Security-Policy blockiert Skripte und Styles direkt im HTML.
const UNIT = "minecraft-paper.service";
const $ = id => document.getElementById(id);
const STATES = { active: "läuft", inactive: "gestoppt", failed: "abgestürzt", activating: "startet …", deactivating: "fährt herunter …" };

function run(args) { return cockpit.spawn(args, { err: "message" }); }

function refresh() {
  run(["systemctl", "show", UNIT, "-p", "ActiveState", "-p", "ActiveEnterTimestamp", "--value"]).then(out => {
    const [state, since] = out.trim().split("\n");
    $("status").className = "status " + state;
    $("statustext").textContent = (STATES[state] || state) + (state === "active" && since ? " seit " + since : "");
  }).catch(e => { $("statustext").textContent = "Status unbekannt: " + e.message; });
  run(["journalctl", "-u", UNIT, "--since", "-24h", "-o", "short-iso", "--no-pager"]).then(out => {
    const lines = out.split("\n").filter(l => /ERROR|Exception|WARN|crash/i.test(l) && !/spark|ViaVersion\] The Vanilla protocol/.test(l));
    $("errors").textContent = lines.length ? lines.slice(-40).join("\n") : "Keine Fehler – alles gut.";
  }).catch(e => { $("errors").textContent = "Log nicht lesbar: " + e.message; });
  run(["journalctl", "-u", UNIT, "-n", "40", "-o", "cat", "--no-pager"]).then(out => { $("log").textContent = out; })
    .catch(e => { $("log").textContent = "Log nicht lesbar: " + e.message; });
}

const armed = {};
function action(verb, btn, label) {
  if (!armed[verb]) {   // erster Klick: nachfragen
    armed[verb] = true; btn.textContent = "Wirklich? Nochmal klicken";
    setTimeout(() => { armed[verb] = false; btn.textContent = label; }, 5000);
    return;
  }
  armed[verb] = false; btn.textContent = label;
  document.querySelectorAll("button").forEach(b => b.disabled = true);
  $("msg").textContent = "Wird ausgeführt …";
  run(["systemctl", "--no-ask-password", verb, UNIT]).then(() => {
    $("msg").textContent = verb === "stop"
      ? "Gestoppt. Achtung: Der Watchdog startet den Server nach spätestens 5 Minuten wieder."
      : "Erledigt. Der Server braucht ca. 40 Sekunden, bis man wieder rein kann.";
  }).catch(e => { $("msg").textContent = "Fehlgeschlagen: " + e.message; })
    .finally(() => { document.querySelectorAll("button").forEach(b => b.disabled = false); refresh(); });
}

[["restart", "Neu starten"], ["start", "Starten"], ["stop", "Stoppen"]].forEach(([verb, label]) => {
  const b = $(verb); b.onclick = () => action(verb, b, label);
});
refresh();
setInterval(refresh, 10000);

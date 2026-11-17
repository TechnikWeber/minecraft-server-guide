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

// ---- Alltagsaufgaben ueber mc-admin (pkexec, siehe setup-cockpit.sh) ----
const ADMIN = ["pkexec", "/usr/local/sbin/mc-admin"];
const MODES = { survival: "Überleben", creative: "Kreativ", adventure: "Abenteuer", spectator: "Zuschauer" };
function admin(args) { return cockpit.spawn(ADMIN.concat(args), { err: "message" }); }
function el(tag, text, cls) { const e = document.createElement(tag); if (text !== undefined) e.textContent = text; if (cls) e.className = cls; return e; }
function say(text, bad) { $("adminmsg").textContent = text; $("adminmsg").className = bad ? "bad" : ""; }
function busy(on) { document.querySelectorAll("#admin button, #admin input, #admin select").forEach(b => { b.disabled = on; }); }

// Zwei Klicks fuer alles, was sich nicht rueckgaengig machen laesst
function confirmClick(btn, label, fn) {
  if (btn.dataset.armed) { delete btn.dataset.armed; btn.textContent = label; fn(); return; }
  btn.dataset.armed = "1"; btn.textContent = "Wirklich? Nochmal klicken";
  setTimeout(() => { if (btn.dataset.armed) { delete btn.dataset.armed; btn.textContent = label; } }, 5000);
}

function doAdmin(args, okText) {
  busy(true); say("Wird ausgeführt …");
  return admin(args).then(out => { say(okText || out.trim() || "Erledigt."); })
    .catch(e => { say("Fehlgeschlagen: " + e.message, true); })
    .finally(() => { busy(false); loadAdmin(); });
}

function size(b) { return b > 1e9 ? (b / 1e9).toFixed(1) + " GB" : Math.round(b / 1e6) + " MB"; }

function loadAdmin() {
  admin(["status"]).then(out => {
    const s = JSON.parse(out);
    $("rconhint").hidden = s.rcon;
    $("rconhint").textContent = s.rcon ? "" : (s.rcon_error || "RCON ist aus.") + " Spieler, Freischalten und Spielregeln brauchen einen laufenden Server mit RCON.";
    $("defmode").textContent = MODES[s.default_gamemode] || s.default_gamemode;
    $("online").textContent = !s.rcon ? "unbekannt (Server aus?)" :
      s.online.length ? s.online.length + (s.max ? " von " + s.max : "") + ": " + s.online.join(", ") : "Niemand online.";
    const dl = $("players"); dl.textContent = "";
    new Set(s.online.concat(s.whitelist)).forEach(n => { const o = el("option"); o.value = n; dl.appendChild(o); });

    $("wlstate").textContent = s.whitelist_on ? "Whitelist ist an: nur eingetragene Spieler kommen rein." : "Whitelist ist aus: jeder mit der Adresse kommt rein.";
    $("wltoggle").textContent = s.whitelist_on ? "Whitelist ausschalten" : "Whitelist einschalten";
    $("wltoggle").dataset.next = s.whitelist_on ? "off" : "on";
    const wl = $("wllist"); wl.textContent = "";
    if (!s.whitelist.length) wl.appendChild(el("li", "Noch niemand eingetragen."));
    s.whitelist.forEach(name => {
      const li = el("li"); li.appendChild(el("span", name));
      const b = el("button", "Entfernen");
      b.onclick = () => confirmClick(b, "Entfernen", () => {
        const bedrock = name.startsWith(".");
        doAdmin(bedrock ? ["whitelist", "remove", name.slice(1), "bedrock"] : ["whitelist", "remove", name]);
      });
      li.appendChild(b); wl.appendChild(li);
    });

    const t = $("rules");
    Object.keys(s.rules).forEach(rule => {
      const info = s.rules[rule], value = s.gamerules[rule];
      let row = document.getElementById("rule-" + rule);
      if (!row) {
        row = el("tr"); row.id = "rule-" + rule;
        const input = el("input"); input.id = "in-" + rule;
        if (info.type === "bool") {
          input.type = "checkbox";
          input.onchange = () => doAdmin(["gamerule", rule, input.checked ? "true" : "false"], info.text + ": " + (input.checked ? "an" : "aus"));
        } else {
          input.type = "number"; input.min = 0; input.max = 100;
          input.onchange = () => doAdmin(["gamerule", rule, String(input.value)], info.text + ": " + input.value);
        }
        const td1 = el("td"); td1.appendChild(input);
        const lab = el("label", info.text); lab.htmlFor = input.id;
        const td2 = el("td"); td2.appendChild(lab); td2.appendChild(el("span", " " + rule, "hint"));
        row.appendChild(td1); row.appendChild(td2); t.appendChild(row);
      }
      const input = document.getElementById("in-" + rule);
      if (document.activeElement !== input) {
        if (info.type === "bool") input.checked = value === "true"; else input.value = value === undefined ? "" : value;
      }
      input.disabled = !s.rcon || value === undefined;
    });

    const bl = $("backups"); bl.textContent = "";
    if (!s.backups.length) bl.appendChild(el("li", "Noch keine Backups."));
    s.backups.forEach(b => {
      const li = el("li");
      li.appendChild(el("span", new Date(b.time * 1000).toLocaleString("de-DE") + " · " + size(b.size)));
      const btn = el("button", "Zurückspielen", "danger");
      btn.onclick = () => confirmClick(btn, "Zurückspielen", () =>
        doAdmin(["restore", b.file]));
      li.appendChild(btn); bl.appendChild(li);
    });
  }).catch(e => {
    $("rconhint").hidden = false;
    $("rconhint").textContent = "Die erweiterten Funktionen fehlen noch: setup-cockpit.sh erneut ausführen (" + e.message + ").";
  });
}

$("modeform").onsubmit = ev => {
  ev.preventDefault();
  const name = $("modename").value.trim(), mode = $("modesel").value;
  doAdmin(["gamemode", mode, name], name + " ist jetzt im Modus " + MODES[mode] + ".");
};
$("wlform").onsubmit = ev => {
  ev.preventDefault();
  const name = $("wlname").value.trim();
  doAdmin($("wlbedrock").checked ? ["whitelist", "add", name, "bedrock"] : ["whitelist", "add", name])
    .then(() => { $("wlname").value = ""; });
};
$("wltoggle").onclick = () => doAdmin(["whitelist", $("wltoggle").dataset.next]);
$("sayform").onsubmit = ev => {
  ev.preventDefault();
  doAdmin(["say", $("saytext").value], "Gesendet.").then(() => { $("saytext").value = ""; });
};
$("backupnow").onclick = () => confirmClick($("backupnow"), "Backup jetzt erstellen", () => doAdmin(["backup"]));

loadAdmin();
setInterval(() => { if (!document.hidden) loadAdmin(); }, 60000);

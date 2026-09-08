#!/bin/bash
# Watchdog fuer den Crossplay-Server. Prueft alle 5 Minuten, ob der Server
# erreichbar ist. Nicht erreichbar -> einmal automatisch neu starten. Klappt
# das nicht, EINMALIGER Alarm mit Befehlen (kein Spam bei Dauerausfall).
set -u
source /usr/local/bin/mc-common.sh

STATE_DOWN="/run/minecraft-paper-watchdog.down"

if in_maintenance; then exit 0; fi

if server_is_up; then
  if [ -f "$STATE_DOWN" ]; then
    rm -f "$STATE_DOWN"
    mc_notify "default" "white_check_mark" "Crossplay: wieder online" "Der Server ist wieder erreichbar."
  fi
  exit 0
fi

systemctl restart "$MC_SERVICE"
sleep 30

if server_is_up; then
  rm -f "$STATE_DOWN"
  mc_notify "default" "arrows_counterclockwise" "Crossplay: automatisch neu gestartet" \
    "Der Server war nicht erreichbar und wurde automatisch neu gestartet. Laeuft wieder.
Falls es haeufiger passiert: journalctl -u $MC_SERVICE -n 80"
  exit 0
fi

if [ ! -f "$STATE_DOWN" ]; then
  touch "$STATE_DOWN"
  mc_notify "urgent" "rotating_light" "Crossplay: Server DOWN" \
    "Server ist unten und der automatische Neustart hat NICHT geholfen. Bitte eingreifen:
1) Status:  systemctl status $MC_SERVICE
2) Logs:    journalctl -u $MC_SERVICE -n 100
3) Port belegt? pkill -f paper.jar ; systemctl start $MC_SERVICE
4) Letztes Backup liegt in $BACKUP_DIR"
fi

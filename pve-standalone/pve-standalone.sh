#!/bin/bash
set -Eeuo pipefail
. /opt/Config/Sync/Scripts/pve-lib-log.sh
FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1
log_new "pve-standalone"

log "Posture check (standalone mode) on $(hostname -s)"
log "== services (pre) =="; systemctl is-active pveproxy pvedaemon pvestatd 2>&1 | tee -a "$LOG_FILE" || true
log "== /etc/pve mount =="; mountpoint /etc/pve 2>&1 | tee -a "$LOG_FILE" || true

log "== disable/mask cluster/HA =="
systemctl stop corosync pve-ha-crm pve-ha-lrm 2>>"$LOG_FILE" || true
systemctl disable corosync pve-ha-crm pve-ha-lrm 2>>"$LOG_FILE" || true
systemctl mask corosync 2>>"$LOG_FILE" || true
[ -d /etc/corosync ] && rm -rf /etc/corosync/* 2>>"$LOG_FILE" || true

log "== pmxcfs local mode =="
systemctl restart pve-cluster || true
sleep 2
mountpoint /etc/pve || journalctl -u pve-cluster --no-pager | tail -n 120 >>"$LOG_FILE" 2>&1 || true

log "== datacenter.cfg (no-quorum-policy: ignore) =="
DC="/etc/pve/datacenter.cfg"; touch "$DC"
grep -q '^no-quorum-policy:' "$DC" 2>/dev/null || echo "no-quorum-policy: ignore" >> "$DC"

if (( FORCE == 1 )); then
  log "== restarting API daemons (forced) ==" 
  systemctl reload-or-restart pvestatd pvedaemon pveproxy || true
else
  log "== skipping daemon restarts (safe mode) =="
  if ! ss -lnt | grep -q ':8006'; then
    log "-- 8006 closed → try-restart pveproxy"
    systemctl try-restart -q pveproxy || true
  fi
fi

log "== sockets/UI =="; ss -lntp | egrep '(:22|:8006)\b' || true
curl -k --max-time 3 https://127.0.0.1:8006/api2/json | head || true
log "== pvesm status =="; pvesm status || true

log_rotate_keep3 "pve-standalone"; log "DONE"

#!/bin/bash
set -Eeuo pipefail

TOOL="pvestandalone"
HOST="$(hostname -s 2>/dev/null || hostname)"
TS="$(date +%F_%H%M%S)"
LOG_DIR="/opt/Config/Fetch/Logs"
LOG="${LOG_DIR}/Log_${TOOL}-${HOST}-${TS}.log"

# Ensure log dir exists; if not, fallback to /root
if ! install -d -m 755 "$LOG_DIR" 2>/dev/null; then
  LOG_DIR="/root"
  LOG="${LOG_DIR}/Log_${TOOL}-${HOST}-${TS}.log"
fi

exec > >(stdbuf -oL tee -a "$LOG") 2>&1

sep(){ printf '\n====================================================================\n'; }
bar(){ printf '\n--------------------------------------------------------------------\n'; }
say(){ printf '[%s] %s\n' "$(date +%F_%T)" "$*"; }

rotate_logs () {
  # keep only 3 newest for this tool
  ls -1t "${LOG_DIR}/Log_${TOOL}-"* 2>/dev/null | tail -n +4 | xargs -r rm -f
}

diagnose () {
  sep; say "DIAG: versions"
  pveversion -v || true
  sep; say "DIAG: cluster services (should be off for single-node)"
  systemctl is-enabled corosync 2>/dev/null || true
  systemctl is-active corosync 2>/dev/null || true
  systemctl is-enabled pve-ha-lrm pve-ha-crm 2>/dev/null || true
  systemctl is-active pve-ha-lrm pve-ha-crm 2>/devnull || true

  sep; say "DIAG: pmxcfs (/etc/pve mount)"
  mountpoint /etc/pve || journalctl -u pve-cluster --no-pager | tail -n 120

  sep; say "DIAG: PVE daemons"
  systemctl --no-pager --full status pvestatd pvedaemon pveproxy | sed -n '1,200p' || true

  sep; say "DIAG: sockets"
  ss -lntp | egrep ':8006|:22' || true
  curl -k --max-time 3 https://127.0.0.1:8006/api2/json | head || true

  sep; say "DIAG: storage"
  pvesm status || true
  sed -n '1,200p' /etc/pve/storage.cfg 2>/dev/null || true

  sep; say "DIAG: recent errors (6h)"
  journalctl --since "6 hours ago" -u pvestatd -u pvedaemon -u pveproxy -u pve-cluster --no-pager | tail -n 400 || true
}

apply_single_node () {
  sep; say "APPLY: enforce single-node posture (no cluster/HA)"
  systemctl disable --now corosync pve-ha-lrm pve-ha-crm || true
  systemctl mask corosync || true
  rm -rf /etc/corosync 2>/dev/null || true

  sep; say "APPLY: ensure pmxcfs in local mode"
  systemctl restart pve-cluster || true
  sleep 2
  mountpoint /etc/pve || journalctl -u pve-cluster --no-pager | tail -n 120

  sep; say "APPLY: datacenter defaults (standalone)"
  cat >/etc/pve/datacenter.cfg <<'EOC'
keyboard: en
console: shell
migration: secure
fencing: false
EOC

  # Optional: strip rbd: stanzas if present (no Ceph desired)
  if egrep -q '^[[:space:]]*rbd:' /etc/pve/storage.cfg 2>/dev/null; then
    cp -a /etc/pve/storage.cfg /etc/pve/storage.cfg.bak.$(date +%F-%H%M%S) 2>/dev/null || true
    awk '
      BEGIN{skip=0}
      /^[[:space:]]*rbd:/ {skip=1}
      /^[[:graph:]]/ && !/^[[:space:]]*rbd:/ && skip==1 {skip=0}
      skip==0 {print}
    ' /etc/pve/storage.cfg > /etc/pve/storage.cfg.clean && mv /etc/pve/storage.cfg.clean /etc/pve/storage.cfg
  fi

  sep; say "APPLY: restart core services"
  systemctl restart pvestatd pvedaemon pveproxy || true

  sep; say "APPLY: verify API"
  ss -lntp | egrep ':8006|:22' || true
  curl -k --max-time 3 https://127.0.0.1:8006/api2/json | head || true

  sep; say "APPLY: guests autostart (no HA/quorum)"
  if command -v qm >/dev/null; then
    for id in $(qm list | awk 'NR>1{print $1}'); do
      qm set "$id" --onboot 1 --startup order=2 >/dev/null 2>&1 || true
    done
  fi
  if command -v pct >/dev/null; then
    for id in $(pct list | awk 'NR>1{print $1}'); do
      pct set "$id" --onboot 1 --startup order=2 >/dev/null 2>&1 || true
    done
  fi
}

usage () {
  cat <<USAGE
${TOOL}  (diagnose by default)

  ${TOOL}           # read-only diagnostics + log
  ${TOOL} --apply   # enforce single-node posture (no cluster/HA), then diagnose
USAGE
}

main () {
  sep; say "START ${TOOL} on ${HOST} (log: ${LOG})"
  case "${1-}" in
    --apply) apply_single_node ;;
    -h|--help) usage; exit 0 ;;
  esac
  diagnose
  rotate_logs
  sep; say "END ${TOOL}"
}
main "$@"

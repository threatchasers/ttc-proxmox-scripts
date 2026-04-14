#!/usr/bin/env bash
# pvediagnostic.sh — Diagnóstico inteligente PVE 8/9 (Debian 12/13)
# - Solo lectura (no cambia estado)
# - Primero evalúa servicios; luego profundiza según errores detectados
# - Rotación de logs: mantener 3
# - Wrapper global: /usr/local/bin/pvediagnostic
# Uso:
#   pvediagnostic                # ventana por defecto (2h)
#   pvediagnostic "6 hours ago"  # ventana custom
#   pvediagnostic --install-only # solo valida instalación y sale

set -euo pipefail

NAME="pvediagnostic"
SCRIPTS_DIR="/opt/Config/Sync/Scripts"
LOGS_DIR="/opt/Config/Fetch/Logs"
WRAPPER="/usr/local/bin/pvediagnostic"

sep(){ echo -e "\n===================================================================="; }
bar(){ echo -e "\n#────────────────────────────────────────────────────────────────────"; }
run(){ bar; echo "# $*"; bar; (eval "$@" 2>&1); }

ensure_paths(){
  [ -d "$SCRIPTS_DIR" ] || mkdir -p "$SCRIPTS_DIR"
  [ -d "$LOGS_DIR" ]    || mkdir -p "$LOGS_DIR"
  # permisos mínimos razonables si están mal
  [ "$(stat -c '%a' "$SCRIPTS_DIR" 2>/dev/null || echo 000)" = "755" ] || chmod 755 "$SCRIPTS_DIR"
  [ "$(stat -c '%a' "$LOGS_DIR" 2>/dev/null || echo 000)"    = "755" ] || chmod 755 "$LOGS_DIR"
  # wrapper global (si falta o apunta mal, rehacer)
  if [ ! -L "$WRAPPER" ] || [ "$(readlink -f "$WRAPPER")" != "$SCRIPTS_DIR/pvediagnostic.sh" ]; then
    ln -sf "$SCRIPTS_DIR/pvediagnostic.sh" "$WRAPPER"
  fi
}

rotate_logs(){
  ls -1t "${LOGS_DIR}/Log_${NAME}-"*.log 2>/dev/null | tail -n +4 | xargs -r rm -f
}

ensure_paths

# modo instalación-sola
if [ "${1:-}" = "--install-only" ]; then
  exit 0
fi

SINCE="${1:-2 hours ago}"
TS="$(date +%F_%H%M%S)"
LOG="${LOGS_DIR}/Log_${NAME}-${TS}.log"
rotate_logs

{
  echo "PVE Diagnostic — ${TS}"
  echo "Host: $(hostname -f 2>/dev/null || hostname)"
  echo "User: $(whoami)    TTY: $(tty || true)"
  echo "Journal window: ${SINCE}"
} | tee "$LOG"

# ── Base del sistema ──
sep | tee -a "$LOG"
run 'date'                             | tee -a "$LOG"
run 'uname -a'                         | tee -a "$LOG"
run 'cat /etc/os-release || true'      | tee -a "$LOG"
run 'pveversion -v || true'            | tee -a "$LOG"
run 'dpkg -l | egrep -i "proxmox|^ii\s+pve-|corosync|libpve|qemu|cluster" || true' | tee -a "$LOG"

# ── Repos/apt ──
sep | tee -a "$LOG"
[ -f /etc/apt/sources.list ] && run 'sed -n "1,200p" /etc/apt/sources.list' | tee -a "$LOG"
for f in /etc/apt/sources.list.d/*.list; do
  [ -f "$f" ] && { echo -e "\n## $f" | tee -a "$LOG"; sed -n "1,200p" "$f" | tee -a "$LOG"; }
done
run 'apt-cache policy | sed -n "1,200p" || true' | tee -a "$LOG"

# ── Red ──
sep | tee -a "$LOG"
run 'ip -br link || true'              | tee -a "$LOG"
run 'ip -br addr || true'              | tee -a "$LOG"
run 'ip route show table all || true'  | tee -a "$LOG"
run 'systemctl status networking --no-pager --full || true' | tee -a "$LOG"
(run 'resolvectl status' || run 'cat /etc/resolv.conf') | tee -a "$LOG"
GW="$(ip r | awk "/default/ {print \$3; exit}")"
echo "Ping GW (${GW})..." | tee -a "$LOG"; ping -c1 -W1 "$GW" 2>&1 | tee -a "$LOG" || true
echo "Ping 8.8.8.8..."    | tee -a "$LOG"; ping -c1 -W1 8.8.8.8     2>&1 | tee -a "$LOG" || true
run 'ss -lntp || true' | tee -a "$LOG"

# ── Servicios núcleo (Fase 1) ──
sep | tee -a "$LOG"
run 'systemctl is-active pve-cluster pvedaemon pveproxy pvestatd corosync || true' | tee -a "$LOG"
run 'systemctl status pve-cluster pvedaemon pveproxy pvestatd corosync --no-pager --full || true' | tee -a "$LOG"
run 'mountpoint /etc/pve || true' | tee -a "$LOG"
run 'findmnt -t fuse.pmxcfs || true' | tee -a "$LOG"

# Journals recientes
sep | tee -a "$LOG"
run 'journalctl -u pve-cluster -u corosync --since "'"$SINCE"'" --no-pager --output=short-iso | tail -n 400 || true' | tee -a "$LOG"
run 'journalctl -u pvedaemon -u pveproxy -u pvestatd --since "'"$SINCE"'" --no-pager --output=short-iso | tail -n 400 || true' | tee -a "$LOG"

# Detectores (Fase 2)
JBUF="$(journalctl --since "$SINCE" --no-pager 2>/dev/null || true)"
PERL_FLAG=0; PMXCFS_FILE_EXISTS=0; AUTHKEY_TRUNC=0; SSL_KEY_FAIL=0
grep -qi 'MIME/Base64\.pm did not return a true value' <<<"$JBUF" && PERL_FLAG=1
grep -qi 'fuse_mount error: File exists'              <<<"$JBUF" && PMXCFS_FILE_EXISTS=1
grep -qi 'Could only read .* of minimum 1024 bits from /etc/corosync/authkey' <<<"$JBUF" && AUTHKEY_TRUNC=1
grep -qi 'pve-ssl\.key.*failed to load local private key' <<<"$JBUF" && SSL_KEY_FAIL=1

echo "[ANALYSIS] PERL=$PERL_FLAG PMXCFS_FILE_EXISTS=$PMXCFS_FILE_EXISTS AUTHKEY_TRUNC=$AUTHKEY_TRUNC SSL_KEY_FAIL=$SSL_KEY_FAIL" | tee -a "$LOG"

# 2.a Perl
if [ "$PERL_FLAG" -eq 1 ]; then
  sep | tee -a "$LOG"
  echo "Perl/MIME::Base64 deep-check" | tee -a "$LOG"
  run 'perl -V 2>&1 | sed -n "1,120p"' | tee -a "$LOG"
  run 'perl -MMIME::Base64 -e '\''print "Loaded MIME::Base64 v$MIME::Base64::VERSION\n"'\'' 2>&1 || true' | tee -a "$LOG"
  run 'ls -l /usr/share/perl5/MIME/Base64.pm 2>/dev/null || true' | tee -a "$LOG"
  run 'dpkg -l | egrep -i "perl|libmime-base64-perl|pve-manager|libpve" || true' | tee -a "$LOG"
fi

# 2.b pmxcfs
if [ "$PMXCFS_FILE_EXISTS" -eq 1 ]; then
  sep | tee -a "$LOG"
  echo "/etc/pve ocupado (pmxcfs)" | tee -a "$LOG"
  run 'ls -lah /etc/pve 2>/dev/null || true' | tee -a "$LOG"
  run 'fuser -vm /etc/pve 2>/dev/null || true' | tee -a "$LOG"
  run 'find /etc/pve -maxdepth 2 -mindepth 1 -printf "%y %p\n" 2>/dev/null || true' | tee -a "$LOG"
fi

# 2.c authkey
if [ "$AUTHKEY_TRUNC" -eq 1 ]; then
  sep | tee -a "$LOG"
  echo "Corosync authkey sospechoso" | tee -a "$LOG"
  run 'ls -l /etc/corosync/authkey 2>/dev/null || true' | tee -a "$LOG"
  run 'stat -c "mode=%a size=%s owner=%U:%G" /etc/corosync/authkey 2>/dev/null || true' | tee -a "$LOG"
  run 'head -c 128 /etc/corosync/authkey 2>/dev/null | hexdump -C || true' | tee -a "$LOG"
fi

# 2.d SSL
if [ "$SSL_KEY_FAIL" -eq 1 ]; then
  sep | tee -a "$LOG"
  echo "pve-ssl.* revisión" | tee -a "$LOG"
  run 'ls -l /etc/pve/local/pve-ssl.* 2>/dev/null || true' | tee -a "$LOG"
  run 'openssl x509 -noout -subject -issuer -dates -in /etc/pve/local/pve-ssl.pem 2>/dev/null || true' | tee -a "$LOG"
fi

# Cluster/quorum (si Perl OK)
sep | tee -a "$LOG"
if perl -e 'use MIME::Base64; 1;' 2>/dev/null; then
  run 'pvecm status' | tee -a "$LOG"
else
  echo "Saltando pvecm status (Perl no carga MIME::Base64)" | tee -a "$LOG"
fi
run 'sed -n "1,200p" /etc/pve/corosync.conf 2>/dev/null || echo "/etc/pve/corosync.conf not present"' | tee -a "$LOG"
run 'sed -n "1,200p" /etc/corosync/corosync.conf 2>/dev/null || true' | tee -a "$LOG"

# UI/puerto 8006
sep | tee -a "$LOG"
run 'ss -lntp | egrep ":8006|:85" || true' | tee -a "$LOG"
run 'curl -k --max-time 2 https://127.0.0.1:8006/api2/json 2>&1 || true' | tee -a "$LOG"

# Storage
sep | tee -a "$LOG"
run 'sed -n "1,300p" /etc/pve/storage.cfg 2>/dev/null || true' | tee -a "$LOG"
run 'pvesm status 2>&1 || true' | tee -a "$LOG"
run 'lsblk -e7 -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT | sed -n "1,400p"' | tee -a "$LOG"
run 'df -hT | sed -n "1,400p"' | tee -a "$LOG"
run 'zpool status 2>/dev/null || true' | tee -a "$LOG"
run 'zfs list 2>/dev/null || true' | tee -a "$LOG"

# Inventario
sep | tee -a "$LOG"
run 'ls -lah /etc/pve/qemu-server 2>/dev/null || true' | tee -a "$LOG"
run 'ls -lah /etc/pve/lxc 2>/dev/null || true' | tee -a "$LOG"

# Resumen
sep | tee -a "$LOG"
PMX_MOUNT="no"; mountpoint /etc/pve >/dev/null 2>&1 && PMX_MOUNT="yes"
echo "[SUMMARY]" | tee -a "$LOG"
echo "- /etc/pve montado: ${PMX_MOUNT}" | tee -a "$LOG"
echo "- Servicios: $(systemctl is-active pve-cluster pvedaemon pveproxy pvestatd corosync 2>/dev/null | tr "\n" " ")" | tee -a "$LOG"
echo "- Perl/MIME::Base64 en journal: $([ "$PERL_FLAG" -eq 1 ] && echo YES || echo NO)" | tee -a "$LOG"
echo "- pmxcfs mountpoint ocupado: $([ "$PMXCFS_FILE_EXISTS" -eq 1 ] && echo YES || echo NO)" | tee -a "$LOG"
echo "- authkey sospechoso: $([ "$AUTHKEY_TRUNC" -eq 1 ] && echo YES || echo NO)" | tee -a "$LOG"
echo "- SSL pve-ssl.* alerta: $([ "$SSL_KEY_FAIL" -eq 1 ] && echo YES || echo NO)" | tee -a "$LOG"

echo -e "\nLog escrito en: $LOG"

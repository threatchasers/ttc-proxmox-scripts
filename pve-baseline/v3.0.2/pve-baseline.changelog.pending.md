## v3.0.2
- Added VAULT mount source analysis and /etc/fstab validation
- Added backing-device analysis for VAULT storage
- Added NVMe detection and scheduler reporting
- Added fstrim.timer validation
- Added TTC health-check service and timer
- Added cleanup for legacy install-proxmox-baseline artifacts
- Added cleanup for stale VAULT-ORION references in TTC-managed files
- Improved status output with storage diagnostics
- Preserved tmpdir at /mnt/pve/VAULT/PVE/tmp and guest temp excludes in vzdump managed block

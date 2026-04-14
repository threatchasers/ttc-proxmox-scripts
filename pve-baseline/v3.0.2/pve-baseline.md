# pve-baseline

## Version
3.0.2

## Premise
Before running this script, VAULT must already exist and be mounted in Proxmox as a local DIR storage.
Recommended TTC standard:
- The filesystem backing /mnt/pve/VAULT should be mounted by /etc/fstab
- Proxmox should use /mnt/pve/VAULT as DIR storage

## Managed files
- /opt/Config/Sync/Scripts/pve-baseline
- /etc/sysctl.d/pve-baseline-mscript.conf
- /etc/profile.d/pve-baseline-mscript-tmpdir.sh
- /etc/systemd/journald.conf.d/pve-baseline-mscript.conf
- /etc/systemd/system/pve-baseline-mscript-swap-clean.service
- /etc/systemd/system/pve-baseline-mscript-swap-clean.timer
- /etc/systemd/system/pve-baseline-mscript-health-check.service
- /etc/systemd/system/pve-baseline-mscript-health-check.timer

## Key behavior
- Detects local DIR storage named VAULT
- Requires VAULT to be already mounted as DIR storage before installation
- Creates VAULT/PVE layout
- Uses /mnt/pve/VAULT/PVE/tmp as Proxmox host temporary backup directory
- Redirects /var/tmp to VAULT
- Keeps /tmp on tmpfs if already tmpfs
- Exports TMPDIR/TMP/TEMP to VAULT tmp
- Rebuilds TTC block in /etc/vzdump.conf
- Excludes guest temporary paths /tmp/* and /var/tmp/* for faster backups
- Applies swap and writeback sysctl tuning
- Applies journald safeguards
- Verifies whether VAULT mount comes from /etc/fstab
- Detects NVMe backing and reports scheduler state
- Verifies fstrim.timer state
- Installs TTC health-check timer
- Cleans legacy install-proxmox-baseline artifacts
- Uses pve-baseline-mscript-* naming for generated files and services

## Modes
- --install
- --run
- --uninstall
- --swap-clean-only
- --health-check-only
- --status

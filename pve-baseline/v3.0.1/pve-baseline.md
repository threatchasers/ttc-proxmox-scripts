# pve-baseline

## Version
3.0.1

## Premise
Before running this script, VAULT must already exist and be mounted in Proxmox as a local DIR storage.

## Managed files
- /opt/Config/Sync/Scripts/pve-baseline
- /etc/sysctl.d/pve-baseline-mscript.conf
- /etc/profile.d/pve-baseline-mscript-tmpdir.sh
- /etc/systemd/journald.conf.d/pve-baseline-mscript.conf
- /etc/systemd/system/pve-baseline-mscript-swap-clean.service
- /etc/systemd/system/pve-baseline-mscript-swap-clean.timer

## Key behavior
- Detects local DIR storage named VAULT
- Requires VAULT to be already mounted as DIR storage before installation
- Creates VAULT/PVE layout
- Uses /mnt/pve/VAULT/PVE/tmp as Proxmox host temporary backup directory
- Redirects /var/tmp to VAULT
- Keeps /tmp on tmpfs if already tmpfs
- Exports TMPDIR/TMP/TEMP to VAULT tmp
- Rebuilds TTC block in /etc/vzdump.conf
- Adds stdexcludes: 1
- Excludes guest temporary paths /tmp/* and /var/tmp/* for faster backups
- Cleans conflicting sysctl files for tracked parameters
- Uses TTC standard paths and log rotation
- Uses pve-baseline-mscript-* naming for generated files and services

## Modes
- --install
- --run
- --uninstall
- --swap-clean-only
- --status

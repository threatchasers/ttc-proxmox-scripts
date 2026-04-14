## v3.0.1
- Updated vzdump managed block to make backup intent explicit
- Added documented tmpdir section pointing to /mnt/pve/VAULT/PVE/tmp
- Added explicit mode: snapshot to vzdump managed block
- Added explicit bwlimit: 0 to vzdump managed block
- Reordered notes and comments inside the managed block for clarity
- Clarified that exclude-path values apply to guest temporary paths, while tmpdir applies to Proxmox host backup staging
- Updated synopsis to state the prerequisite that VAULT must already exist and be mounted as local DIR storage before running the script

## v3.0.0
- Renamed script from install-proxmox-baseline to pve-baseline
- Standardized generated files and services under pve-baseline-mscript-*
- SYSCTL file is now /etc/sysctl.d/pve-baseline-mscript.conf
- TMPDIR profile file is now /etc/profile.d/pve-baseline-mscript-tmpdir.sh
- journald drop-in file is now /etc/systemd/journald.conf.d/pve-baseline-mscript.conf
- systemd service is now /etc/systemd/system/pve-baseline-mscript-swap-clean.service
- systemd timer is now /etc/systemd/system/pve-baseline-mscript-swap-clean.timer
- Removed embedded full changelog management from the script
- Script now only ensures the external changelog exists
- Script now generates a pending changelog block for manual review
- Preserved TTC-managed sysctl consolidation
- Preserved tmpfs /tmp behavior when already in use
- Preserved vzdump stdexcludes: 1

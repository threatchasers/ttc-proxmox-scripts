## v3.0.1
- Updated vzdump managed block to make backup intent explicit
- Added documented tmpdir section pointing to /mnt/pve/VAULT/PVE/tmp
- Added explicit mode: snapshot to vzdump managed block
- Added explicit bwlimit: 0 to vzdump managed block
- Reordered notes and comments inside the managed block for clarity
- Clarified that exclude-path values apply to guest temporary paths, while tmpdir applies to Proxmox host backup staging
- Updated synopsis to state the prerequisite that VAULT must already exist and be mounted as local DIR storage before running the script

# pve-backup changelog

## v1.8.0
- Added final execution summary for remote destinations.
- Added per-destination elapsed time logging.
- Avoided unnecessary network pre-checks for local `dir` storages.
- Added `--restore-plan`.
- `--restore-plan` now searches local and remote backup roots, selects the newest snapshot, and prints a guided recovery plan.
- Preserved resilient skip-and-continue behavior for slow or unreachable remote storages.

## v1.7.4
- Added tolerant NFS server pre-check before touching remote NFS storages.
- Added `NETWORK_CHECK_TIMEOUT=15` for cloud-backed or high-latency NFS servers.
- Added `get_nfs_server()` parser to read NFS server address from `/etc/pve/storage.cfg`.
- NFS storages now log `slow or unreachable` instead of being treated as instantly dead.
- Preserved skip-and-continue behavior when a remote storage is unavailable.
- Kept backup flow resilient across mixed local, NFS, and cloud-backed storage environments.

## v1.7.3
- Cleaned remote error handling so unreachable storages no longer print raw `mkdir` stderr into the main log.
- Suppressed stderr for timeout-wrapped remote `test`, `stat`, `mountpoint`, `mkdir`, and `rsync`.
- Added clearer TTC log messages:
  - storage was not reachable
  - destination skipped
  - sync completed
- Preserved 3-minute bounded timeout behavior for all remote storage operations.
- Kept backup flow resilient when individual remote storages fail.

## v1.7.2
- Added 3-minute bounded timeout for all remote storage operations.
- Added bounded reachability checks for every storage using timeout-wrapped `test`, `stat`, and `mountpoint`.
- Added bounded `mkdir -p` and `rsync` for all remote targets.
- Added explicit log messages when a storage is not reachable.
- Ensured unreachable storages are skipped without breaking local backup or other destinations.
- Fixed `install` flow by loading env defaults before rendering the timer file.
- Increased default `RSYNC_TIMEOUT` to 180 seconds.
- Added `STORAGE_OP_TIMEOUT=180` configuration.

## v1.7.1
- Fixed runtime failures caused by invalid working directory (`getcwd` / `rsync` code 3).
- Forced safe working directory at script startup.
- Added `WorkingDirectory=/` to the systemd service.
- Added `cd / || cd /root` in the wrapper before execution.
- Kept TTC remote support and local path redesign.
- Preserved retention rules:
  - Local keep=1
  - VAULT keep=1
  - BACKUPS keep=3
  - TTC keep=1

## v1.7.0
- Added support for storages whose ID contains `TTC`.
- Added TTC remote path rule:
  - `<storage-path>/Nodes/<last3octets>/PVE-Backup/<timestamp>`
- Added TTC retention policy `keep=1`.
- Changed local backup root from:
  - `/opt/Config/Fetch/Backups/Nodes/PVE/<node-ip>/...`
  to:
  - `/opt/Config/Fetch/Backups/Nodes/<last3octets>/PVE-Backup/<timestamp>`
- Preserved remote readiness checks so disconnected TTC storages do not break the backup workflow.
- Kept local backup successful even if TTC remote sync fails.

## v1.6.2
- Added remote storage readiness validation before rsync.
- Added mountpoint verification for `nfs` and `cifs` storages.
- Added `rsync --timeout=120` to reduce hanging on broken remote mounts.
- Added per-destination success/failure logging for `VAULT` and `BACKUPS`.
- Remote sync failures no longer imply local backup failure.
- Improved operational safety for disconnected or stale remote storage paths.

## v1.6.1
- Fixed `--install` so it no longer fails when the script is already located at `/opt/Config/Sync/Scripts/pve-backup`.
- Preserved TTC standard install behavior with wrapper, service, timer, env file, and log rotation.
- Confirmed working automatic schedule with `systemd timer`.

## v1.6.0
- Added dual remote destination policy:
  - storages containing `VAULT` with retention `keep=1`
  - storages containing `BACKUPS` with retention `keep=3`
- Added local retention `keep=1`
- Added storage discovery by parsing `/etc/pve/storage.cfg`
- Added restore-friendly backup tree instead of flat snapshot layout.
- Added `_meta` backup data for node reconstruction.
- Added systemd timer and oneshot service integration.

## v1.5.1
- Changed backup layout to preserve source directory tree for easier restore operations.
- Introduced `_meta/` directory inside each snapshot.
- Expanded disaster recovery content set for node rebuild workflows.
- Refined local and remote snapshot handling for structure consistency.

## v1.5.0
- Reintroduced real backup copy logic instead of only creating remote directories.
- Added local snapshot creation under `/opt/Config/Fetch/Backups/Nodes/PVE/<NODE_IP>/<TIMESTAMP>`.
- Added remote sync to matching storage path from `storage.cfg`.
- Fixed earlier regression where remote destination path was created but remained empty.

## v1.4.0
- Changed storage path resolution to use `/etc/pve/storage.cfg`.
- Changed short IP mode to `last3octets`.
- Fixed unsafe `BASH_REMATCH` parsing flow that could break remote path discovery.
- Added env-driven behavior for backup label and matching logic.
- Improved backup destination diagnostics.

## v1.3.2
- Stabilized TTC script structure and initial env-based configuration support.
- Standardized script placement under `/opt/Config/Sync/Scripts`.
- Standardized logs under `/opt/Config/Fetch/Logs`.
- Added wrapper support and systemd-based execution model.
- Established baseline for Proxmox node configuration backup workflow.

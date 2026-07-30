# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- Limit the `lvmetad` check to RHEL 7 clusters; on RHEL 8+ report that the check is not needed (lvmetad was removed), avoiding false warnings when `use_lvmetad` is absent from `lvm.conf`.

### Added

- Added corosync rrp_mode check.
- Added corosync transport protocol check.
- Added detection for Fujitsu Primecluster.
- Added check that fails when a Resilient Storage cluster has only `fence_kdump` stonith devices.

## [1.1.1]

### Added

- Added support for detecting Oracle VM (Oracle Xen) platforms.
- Added support for Red Hat High Availability clusters running on Nutanix virtual machines.
- Added STONITH validation to check that:
  - at least one STONITH device is configured;
  - not all configured STONITH devices are disabled.

### Fixed

- Fixed detection of LINBIT, IBM, and third-party clusters.
- Fixed STONITH detection to avoid false positives when the cluster is stopped.
- Corrected the fencing/STONITH documentation link in the General Requirements section.

## [1.1.0]

### Changed

- Temporary comparison files default to `${TMPDIR:-/tmp}/rhel-ha-advisor` instead of requiring a CLI argument.
- Override the temp base directory with `RHEL_HA_ADVISOR_TMPDIR` or `tmp_dir` in `~/.config/rhel-ha-advisor/config`.

### Removed

- The second positional argument `PATH-TO-TMPFILES`.

### Fixed

- Avoid errors when sosreports omit the dmidecode output file (hardware check).
- Avoid errors when sosreports omit the DNF repolist file (RHUI check).

## [1.0.0]

### Added

- Initial release.

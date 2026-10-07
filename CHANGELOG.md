# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Added verification of the number of nodes in Resilient Storage clusters.
- Added verification of the number of corosync rings in Resilient Storage clusters.

### Removed

- Resilient storage checks (kdump & withdraw) are not included in the report anymore if the cluster is not a Resilient Storage.
- lvmetad check is not included anymore in the report if the nodes don't run RHEL 7.

## [1.1.2]

### Fixed

- Limit the `lvmetad` check to RHEL 7 clusters; on RHEL 8+ report that the check is not needed (lvmetad was removed), avoiding false warnings when `use_lvmetad` is absent from `lvm.conf`.

### Added

- Added corosync rrp_mode check.
- Added corosync transport protocol check.
- Added detection for Fujitsu Primecluster.
- Added check that fails when a Resilient Storage cluster has only `fence_kdump` stonith devices.
- Added check to ensure the cluster is registered in a quorum device using the right algorithm.
- Added check to ensure the quorum device is not hosted in one of the cluster nodes.
- Added detection for XFUSION servers

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

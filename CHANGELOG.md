# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

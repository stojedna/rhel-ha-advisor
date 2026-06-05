# RHEL HA Advisor

Quick CLI tool to review unpacked sosreports for Red Hat High Availability and Resilient Storage cluster installations. Supports standard `sosreport` and `soscleaner` output.

It compares sosreports from the same cluster against Red Hat support policies for HA and Resilient Storage, and reports where the configuration may fall outside what Red Hat supports. A cluster summary is shown first, followed by installation checks and additional health and diagnostic findings.

# Installation

| Method | Best for |
|--------|----------|
| [COPR (dnf)](#copr-recommended-on-fedora) | Fedora systems — install and get updates with `dnf` |
| [From source (make)](#from-source) | Developers or custom install paths |
| [Run from clone](#run-without-installing) | Quick try from a git checkout |

Pre-built packages are published on COPR: [jblanco/rhel-ha-advisor](https://copr.fedorainfracloud.org/coprs/jblanco/rhel-ha-advisor/).

## COPR (recommended on Fedora)

Install `dnf-plugins-core` if `dnf copr` is not available, then enable the repository and install the package:

```bash
sudo dnf install dnf-plugins-core
sudo dnf copr enable jblanco/rhel-ha-advisor
sudo dnf install rhel-ha-advisor
```

To remove the COPR repository later:

```bash
sudo dnf copr disable jblanco/rhel-ha-advisor
```

Upgrade when a new build is published:

```bash
sudo dnf upgrade rhel-ha-advisor
```

## From source

Clone the repository and install with `make`:

```bash
git clone https://github.com/stojedna/rhel-ha-advisor.git
cd rhel-ha-advisor
```

| Command | Install location |
|---------|------------------|
| `make install` | `/usr/local/bin`, `/usr/local/share/rhel-ha-advisor` (default) |
| `sudo make install PREFIX=/usr` | `/usr/bin`, `/usr/share/rhel-ha-advisor` (same layout as the RPM) |
| `make install PREFIX=$HOME/.local` | `$HOME/.local/bin`, `$HOME/.local/share/rhel-ha-advisor` |

Ensure `~/.local/bin` is on your `PATH` when using a user-local install.

Uninstall:

```bash
make uninstall
# or: sudo make uninstall PREFIX=/usr
```

## Run without installing

From a clone, invoke the script directly:

```bash
./rhel-ha-advisor PATH-TO-SOSREPORTS PATH-TO-TMPFILES
```

# How to run

```bash
rhel-ha-advisor [OPTIONS] PATH-TO-SOSREPORTS PATH-TO-TMPFILES
```

## Arguments

| Argument | Description |
|----------|-------------|
| `PATH-TO-SOSREPORTS` | Directory containing unpacked sosreport folders |
| `PATH-TO-TMPFILES` | Base directory where a unique 8-digit work folder is created for temporary comparison files |

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show usage and exit |
| `-V`, `--version` | Show version and exit |
| `--no-color` | Disable colored output |

## Workflow

1. Point the tool at a directory with unpacked sosreport folders.
2. The tool lists the available folder names.
3. You are prompted interactively for each sosreport folder to include in the analysis.
4. The first sosreport is used to detect cluster type and node count; additional prompts follow for the remaining nodes.
5. Results are printed to the terminal.

Sosreport folders can be either:

- **Direct layout:** `sosreport-hostname-.../installed-rpms`, `etc/`, `sos_commands/`, etc.
- **Wrapped layout:** `folder-name/inner-hostname-dir/installed-rpms`, etc.

# Example execution

```bash
$ rhel-ha-advisor ~/sosreports /tmp/rhel-ha-advisor-work
```

```
Sosreports directory: /home/user/sosreports
Temporary files will be created in: /tmp/rhel-ha-advisor-work/48291037

sosreport-node1-2025-08-20-abc123
sosreport-node2-2025-08-20-def456

(1) Enter the sosreport folder name: sosreport-node1-2025-08-20-abc123
(2) Enter the sosreport folder name: sosreport-node2-2025-08-20-def456

```

![Report Example](images/report-example.png)

# Current features

## Cluster summary

- Cluster name detection
- Node count
- Pacemaker and Corosync package versions
- Version mismatch detection across nodes

## Installation and health checks

- Developer subscription usage
- RHUI repository detection
- Supported hardware / virtualization platform checks
- RHEL version consistency across nodes
- Cluster package version consistency
- Kernel version consistency
- Corosync configuration sync
- `lvmetad` status on RHEL 7 clusters
- `corosync-qnetd` package presence
- `no-quorum-policy` validation
- `stonith-enabled` validation
- Technology Preview feature detection (RHEL 7 and 8)
- Remote and guest node detection
- GFS2 withdraw checks

## Additional stats and debug checks

- Third-party applications known to interfere with clusters
- `ha-resourcemon.sh` configuration
- `trace_ra` usage
- Pacemaker debug settings

# Output format

Check results are shown in ASCII tables with colored status labels:

| Status | Meaning |
|--------|---------|
| `PASS` | Check passed (green) |
| `FAIL` | Check failed (red); related KCS links may be shown |
| `WARN` | Warning (yellow) |
| `INFO` | Informational result (blue) |

Use `--no-color` to disable terminal colors.

# Scope

- Red Hat Enterprise Linux 7 and newer clustered environments based on Corosync/Pacemaker.

# Project layout

```
rhel-ha-advisor              CLI entry point
lib/functions.sh             Check functions and report logic
Makefile                     Install/uninstall targets
LICENSE                      GPL-2.0-or-later
images/                      Example screenshots
```

# License

This project is licensed under the **GNU General Public License v2.0 or later**. See [LICENSE](LICENSE).

-----

This project is not developed, provided, or supported by Red Hat.

The tool is under active development. Suggestions and issue reports are welcome.

-----

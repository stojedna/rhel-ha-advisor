# Fedora / COPR spec for rhel-ha-advisor
#
# Local build (after tagging v%{version} and publishing the archive URL):
#   spectool -g -R packaging/rhel-ha-advisor.spec
#   rpmbuild -ba packaging/rhel-ha-advisor.spec
#
# COPR: point SCM at this repo and set "Spec file" to packaging/rhel-ha-advisor.spec

Name:           rhel-ha-advisor
Version:        1.1.2
Release:        1%{?dist}
Summary:        Review RHEL HA cluster sosreports offline

# Add a LICENSE file upstream and keep this in sync.
License:        GPL-2.0-or-later
URL:            https://github.com/stojedna/rhel-ha-advisor
# Update URL when the canonical upstream is published.
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  make
BuildRequires:  ShellCheck

Requires:       bash
Requires:       coreutils
Requires:       diffutils
Requires:       findutils
Requires:       gawk
Requires:       grep
Requires:       jq
Requires:       sed

%description
RHEL HA Advisor is a CLI tool that analyzes unpacked sosreport archives from
Red Hat High Availability (Pacemaker/Corosync) clusters. It compares multiple
node reports, prints a cluster summary, and runs installation, health, and
diagnostic checks with pass/fail/warn results.

%prep
%autosetup -n %{name}-%{version}

%build
# no build step

%install
make install PREFIX=%{_prefix} DESTDIR=%{buildroot}

%check
shellcheck -x rhel-ha-advisor lib/functions.sh

%files
%doc README.md CHANGELOG.md
%{_bindir}/rhel-ha-advisor
%{_datadir}/%{name}/lib/functions.sh

%changelog
* Sat Aug 29 2026 Javier Blanco <javier@jblanco.es> - 1.1.2-1
- Update to 1.1.2; see CHANGELOG.md for details


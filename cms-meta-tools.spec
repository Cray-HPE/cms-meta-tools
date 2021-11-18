# Copyright 2021 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# (MIT License)

Name: cms-meta-tools
License: MIT
Summary: Backend tools used to build and support CMS projects
Group: System/Management
# The placeholder version string will be replaced at repo build time by
# the BuildPrep script
Version: @VERSION@
Release: %(echo ${BUILD_METADATA})
# At this point the RPM contains no binaries that would make it
# architecture-specific
BuildArch: noarch
Source: %{name}-%{version}.tar.bz2
Vendor: Cray Inc.
Requires: bash
Requires: git >= 1.8.3
# Needed for gofmt tool
Requires: go
Requires: python3 >= 3.6
# We want this to be relocatable to whatever directory the user desires
Prefix: /opt/cray/cms-meta-tools

# Defines
%define cmtdir /opt/cray/cms-meta-tools
%define clcdir %{cmtdir}/copyright_license_check
%define ffdir %{cmtdir}/file_filter
%define gidir %{cmtdir}/git_info
%define gldir %{cmtdir}/go_lint
%define lvdir %{cmtdir}/latest_version
%define uadir %{cmtdir}/update_appversion
%define uvdir %{cmtdir}/update_versions
%define scdir %{cmtdir}/scripts
%define utdir %{cmtdir}/utils

%description
Backend tools used to build and support Cray CMS projects

%prep
%setup -q

%build

%install
install -m 755 -d                                                   %{buildroot}%{cmtdir}/
install -m 755 version.py                                           %{buildroot}%{cmtdir}

install -m 755 -d                                                   %{buildroot}%{clcdir}/
install -m 755 copyright_license_check/copyright_license_check.sh   %{buildroot}%{clcdir}
install -m 644 copyright_license_check/copyright_license_check.yaml %{buildroot}%{clcdir}

install -m 755 -d                                                   %{buildroot}%{ffdir}/
install -m 755 file_filter/file_filter.py                           %{buildroot}%{ffdir}
install -m 755 file_filter/file_filter.sh                           %{buildroot}%{ffdir}

install -m 755 -d                                                   %{buildroot}%{gidir}/
install -m 755 git_info/git_info.sh                                 %{buildroot}%{gidir}

install -m 755 -d                                                   %{buildroot}%{gldir}/
install -m 755 go_lint/go_lint.sh                                   %{buildroot}%{gldir}
install -m 644 go_lint/go_lint.yaml                                 %{buildroot}%{gldir}

install -m 755 -d                                                   %{buildroot}%{lvdir}/
install -m 755 latest_version/latest_version.py                     %{buildroot}%{lvdir}
install -m 755 latest_version/latest_version.sh                     %{buildroot}%{lvdir}
install -m 755 latest_version/update_external_versions.sh           %{buildroot}%{lvdir}

install -m 755 -d                                                   %{buildroot}%{scdir}/
install -m 755 scripts/runBuildPrep.sh                              %{buildroot}%{scdir}
install -m 755 scripts/runLint.sh                                   %{buildroot}%{scdir}
install -m 755 scripts/update-chart-app-version.sh                  %{buildroot}%{scdir}

install -m 755 -d                                                   %{buildroot}%{uadir}/
install -m 755 update_appversion/update_appversion.py               %{buildroot}%{uadir}

install -m 755 -d                                                   %{buildroot}%{uvdir}/
install -m 755 update_versions/update_versions.sh                   %{buildroot}%{uvdir}

install -m 755 -d                                                   %{buildroot}%{utdir}/
install -m 644 utils/pyyaml.sh		                                %{buildroot}%{utdir}

%clean
rm -f %{buildroot}%{clcdir}/copyright_license_check.sh
rm -f %{buildroot}%{clcdir}/copyright_license_check.yaml
rmdir %{buildroot}%{clcdir}

rm -f %{buildroot}%{ffdir}/file_filter.py
rm -f %{buildroot}%{ffdir}/file_filter.sh
rmdir %{buildroot}%{ffdir}

rm -f %{buildroot}%{gidir}/git_info.sh
rmdir %{buildroot}%{gidir}

rm -f %{buildroot}%{gldir}/go_lint.sh
rm -f %{buildroot}%{gldir}/go_lint.yaml
rmdir %{buildroot}%{gldir}

rm -f %{buildroot}%{lvdir}/latest_version.py
rm -f %{buildroot}%{lvdir}/latest_version.sh
rm -f %{buildroot}%{lvdir}/update_external_versions.sh
rmdir %{buildroot}%{lvdir}

rm -f %{buildroot}%{scdir}/runBuildPrep.sh
rm -f %{buildroot}%{scdir}/runLint.sh
rm -f %{buildroot}%{scdir}/update-chart-app-version.sh
rmdir %{buildroot}%{scdir}

rm -f %{buildroot}%{utdir}/pyyaml.sh
rmdir %{buildroot}%{utdir}

rm -f %{buildroot}%{uadir}/update_appversion.py
rmdir %{buildroot}%{uadir}

rm -f %{buildroot}%{uvdir}/update_versions.sh
rmdir %{buildroot}%{uvdir}

rm -f %{buildroot}%{cmtdir}/version.py
rmdir %{buildroot}%{cmtdir}

%files
%attr(-,root,root)
%dir %{cmtdir}
%attr(755, root, root) %{cmtdir}/version.py

%dir %{clcdir}
%attr(755, root, root) %{clcdir}/copyright_license_check.sh
%attr(644, root, root) %{clcdir}/copyright_license_check.yaml

%dir %{ffdir}
%attr(755, root, root) %{ffdir}/file_filter.py
%attr(755, root, root) %{ffdir}/file_filter.sh

%dir %{gidir}
%attr(755, root, root) %{gidir}/git_info.sh

%dir %{gldir}
%attr(755, root, root) %{gldir}/go_lint.sh
%attr(644, root, root) %{gldir}/go_lint.yaml

%dir %{lvdir}
%attr(755, root, root) %{lvdir}/latest_version.py
%attr(755, root, root) %{lvdir}/latest_version.sh
%attr(755, root, root) %{lvdir}/update_external_versions.sh

%dir %{scdir}
%attr(755, root, root) %{scdir}/runBuildPrep.sh
%attr(755, root, root) %{scdir}/runLint.sh
%attr(755, root, root) %{scdir}/update-chart-app-version.sh

%dir %{uadir}
%attr(755, root, root) %{uadir}/update_appversion.py

%dir %{uvdir}
%attr(755, root, root) %{uvdir}/update_versions.sh

%dir %{uvdir}
%attr(644, root, root) %{utdir}/pyyaml.sh

%changelog

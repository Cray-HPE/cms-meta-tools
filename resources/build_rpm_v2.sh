#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2025 Hewlett Packard Enterprise Development LP
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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

set -exuo pipefail

# Usage: build_rpm.sh [--arch <rpm-arch>] <outdir> <rpm_name> <rpm_version> <source_tar> <spec_file_basename>
#
# output directory must be a relative path
#
# If --arch is not specified, it will be determined from the build environment.
#
# Supported arch values: x86_64, aarch64, noarch

echo "$0 called with $# arguments: $*"

function err_exit {
  echo "$(basename $0): ERROR: $*" >&2
  exit 1
}

arch=""

function valid_arch {
  [[ $1 == noarch || $1 == x86_64 || $1 == aarch64 ]] && return 0 || return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    "--arch")
      [[ -z ${arch} ]] || err_exit "$1 should not be specified more than once"
      [[ $# -ge 2 ]] || err_exit "$1 option requires an argument"
      valid_arch "$2" || err_exit "Invalid $1 value: '$2'"
      arch="$2"
      ;;
     *)
      break
      ;;
  esac
  shift 2
done

[[ $# -eq 5 ]] || err_exit "Exactly 5 positional arguments required, but received $#. Invalid argument(s): $*"

[[ -n $1 ]] || err_exit "Output directory may not be blank"
[[ ! $1 =~ ^/ ]] || err_exit "Output directory may not begin with /. Invalid: '$1'"
out_reldir="$1"

shift

# Just make sure the RPM name isn't blank and doesn't include any whitespace, >, <, or =
name_regex='^[^[:space:]<>=]+$'
[[ -n $1 ]] || err_exit "RPM name may not be blank"
[[ $1 =~ ${name_regex} ]] || err_exit "Specified RPM name ('$1') contains illegal characters (whitespace, <, >, or =)"
RPM_NAME="$1"

shift

# Version/Release strings allowed to have ASCII letters (a-zA-Z), digits (0-9) and separators (._+~)
[[ -n $1 ]] || err_exit "RPM version may not be blank"
ver_regex='^[._+~0-9a-zA-Z]+$'
[[ $1 =~ ${ver_regex} ]] || err_exit "Specified RPM version ('$1') contains illegal characters"
RPM_VERSION="$1"

shift

[[ $1 =~ \.tar$ ]] || err_exit "Source tar must end with .tar"
[[ -e $1 ]] || err_exit "Source tar does not exist: '$1'"
[[ -f $1 ]] || err_exit "Source tar exists but is not a regular file: '$1'"
source_tar="$1"

shift

[[ -n $1 ]] || err_exit "Spec file basename may not be blank"
spec_file_base="$1"

if [[ -z ${arch} ]]; then
  echo "No arch specified. Getting default value"
  RPM_ARCH=$(uname -i)
  valid_arch "${RPM_ARCH}" || err_exit "Invalid arch value reported by unamne -i: '${RPM_ARCH}'"
else
  RPM_ARCH="${arch}"
fi

echo "out_reldir='${out_reldir}' spec_file_base='${spec_file_base}' source_tar='${source_tar}' RPM_ARCH='${RPM_ARCH}'"
echo "RPM_NAME='${RPM_NAME}' RPM_VERSION='${RPM_VERSION}'"
export RPM_ARCH RPM_NAME RPM_VERSION

UNTAR_DIR=$(mktemp -d $(pwd)/.tmp.untar.XXX)
BUILD_DIR=$(mktemp -d $(pwd)/.tmp.build.XXX)

tar -C "${UNTAR_DIR}" -xvf "${source_tar}"
spec_file_path="${UNTAR_DIR}/${spec_file_base}"
[[ -e ${spec_file_path} ]] || err_exit "Spec file (${spec_file_base}) does not exist in source tarfile (${source_tar})"
[[ -f ${spec_file_path} ]] || err_exit "Spec file (${spec_file_base}) exists in source tarfile (${source_tar}) but is not a regular file"

OUT_DIR="$(pwd)/${out_reldir}"

SOURCE_NAME="${RPM_NAME}-${RPM_VERSION}"
export SOURCE_BASENAME="${SOURCE_NAME}.tar.bz2"
SOURCE_PATH="${BUILD_DIR}/SOURCES/${SOURCE_BASENAME}"

mkdir -pv "${OUT_DIR}/RPMS/${RPM_ARCH}" "${OUT_DIR}/SRPMS" "${BUILD_DIR}/SRPMS" "${BUILD_DIR}/SPECS" "${BUILD_DIR}/SOURCES"
cp -v "${spec_file_path}" "${BUILD_DIR}/SPECS/"

#ls -al "${BUILD_DIR}/SPECS/${spec_file_base}"

# Create source tarball
tar -C "${UNTAR_DIR}" --transform "flags=r;s,^,/${SOURCE_NAME}/," -cvjf "${SOURCE_PATH}" .

#ls -al "${BUILD_DIR}/SPECS/${spec_file_base}"

pushd "${BUILD_DIR}"

#ls -al "${BUILD_DIR}/SPECS/${spec_file_base}"

# Build SRC RPM
rpmbuild -ts "${SOURCE_PATH}" --target "${RPM_ARCH}" --define "_topdir ${BUILD_DIR}"

#ls -al "${BUILD_DIR}/SPECS/${spec_file_base}"

cp -v "${BUILD_DIR}/SRPMS/"*.rpm "${OUT_DIR}/SRPMS"

#ls -al "${BUILD_DIR}/SPECS/${spec_file_base}"

# Build main RPM
rpmbuild -ba "${spec_file_path}" --target "${RPM_ARCH}" --define "_topdir ${BUILD_DIR}"
cp -v "${BUILD_DIR}/RPMS/${RPM_ARCH}"/*.rpm "${OUT_DIR}/RPMS/${RPM_ARCH}"

popd

# Cleanup temp dirs
rm -rfv "${BUILD_DIR}" "${UNTAR_DIR}"

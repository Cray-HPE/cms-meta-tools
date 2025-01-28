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

# Usage: build_rpm.sh [--label <label-string>]
#                     [--arch <rpm-arch>]
#                     <build-reldir> <rpm_name> <rpm_version> <source_tar> <spec_file_basename>
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

num_required_positional_args=5
[[ $# -le ${num_required_positional_args} ]] || err_exit "Too many arguments. Unrecognized argument: $1"
[[ $# -eq ${num_required_positional_args} ]] || err_exit "Too few arguments specified"

[[ -n $1 ]] || err_exit "Build reldir may not be blank"
[[ ! $1 =~ ^/ ]] || err_exit "Build reldir may not begin with /. Invalid: '$1'"
BUILD_RELDIR="$1"

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
  arch=$(uname -i)
  valid_arch "${arch}" || err_exit "Invalid arch value reported by unamne -i: '${arch}'"
fi

RPM_ARCH="${arch}"
SPEC_FILE="${spec_file_base}"

export SPEC_FILE RPM_NAME RPM_VERSION RPM_ARCH

echo "RPM_NAME='${RPM_NAME}' RPM_VERSION='${RPM_VERSION}' RPM_ARCH='${RPM_ARCH}' BUILD_RELDIR='${BUILD_RELDIR}'"
echo "SPEC_FILE='${SPEC_FILE}' source_tar='${source_tar}'"

reldir=$(echo ".tmp.${RPM_ARCH}.${RPM_NAME}.${RPM_VERSION}" | tr '/' '_')
temp_build_root=$(mktemp -d $(pwd)/${reldir}.XXX)

tar -C "${temp_build_root}" -xvf "${source_tar}"
spec_file_path="${temp_build_root}/${SPEC_FILE}"
[[ -e ${spec_file_path} ]] || err_exit "Spec file (${SPEC_FILE}) does not exist in source tarfile (${source_tar})"
[[ -f ${spec_file_path} ]] || err_exit "Spec file (${SPEC_FILE}) exists in source tarfile (${source_tar}) but is not a regular file"

MAIN_BUILD_DIR="$(pwd)/${BUILD_RELDIR}"

BUILD_DIR="${temp_build_root}/${BUILD_RELDIR}"
SOURCE_NAME="${RPM_NAME}-${RPM_VERSION}"
export SOURCE_BASENAME="${SOURCE_NAME}.tar.bz2"
SOURCE_PATH="${BUILD_DIR}/SOURCES/${SOURCE_BASENAME}"

mkdir -pv "${BUILD_RELDIR}/RPMS/${RPM_ARCH}" "${BUILD_RELDIR}/SRPMS" "${BUILD_DIR}/SPECS" "${BUILD_DIR}/SOURCES"
cp -v "${SPEC_FILE}" "${BUILD_DIR}/SPECS/"

pushd "${temp_build_root}"

# Create source tarball
tar --transform "flags=r;s,^,/${SOURCE_NAME}/," --exclude ./dist -cvjf "${SOURCE_PATH}" .

# Build SRC RPM
rpmbuild -ts "${SOURCE_PATH}" --target "${RPM_ARCH}" --define "_topdir ${BUILD_DIR}"
cp -v "${BUILD_DIR}/SRPMS/"*.rpm "${MAIN_BUILD_DIR}/SRPMS"

# Build main RPM
rpmbuild -ba "${SPEC_FILE}" --target "${RPM_ARCH}" --define "_topdir ${BUILD_DIR}"
cp -v "${BUILD_DIR}/RPMS/${RPM_ARCH}"/*.rpm "${MAIN_BUILD_DIR}/RPMS/${RPM_ARCH}"

popd

# Cleanup temp dir
rm -rfv "${temp_build_root}"

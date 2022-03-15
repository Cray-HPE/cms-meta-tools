#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
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
MYDIR="file_filter"
MYNAME="file_filter.sh"

function info
{
    echo "$MYNAME: $*" 1>&2
}

function err_exit
{
    info "ERROR: $*" 1>&2
    exit 1
}

function run_cmd_verify_dir
{
    out=$("$@") || err_exit "Command failed: $*"
    [ -n "$out" ] || err_exit "Command gave blank outut: $*"
    [ -e "$out" ] || err_exit "Nonexistent path ($out) given by command: $*"
    [ -d "$out" ] || err_exit "Non-directory path ($out) given by command: $*"
}

[ -n "${CMS_META_TOOLS_PATH}" ] && info "CMS_META_TOOLS_PATH is set to $CMS_META_TOOLS_PATH"

# If CMS_META_TOOLS_PATH variable is set to a valid value, we will defer to that
if [ -n "${CMS_META_TOOLS_PATH}" ] && [ -f "${CMS_META_TOOLS_PATH}/${MYDIR}/${MYNAME}" ]; then
    info "Using value from CMS_META_TOOLS_PATH variable"
    MYDIR_PATH="${CMS_META_TOOLS_PATH}/${MYDIR}"
# In this case, let's first try realpath, since it gives us the cleanest paths
elif realpath / >/dev/null 2>&1 ; then
    # realpath is available, so let's use that
    run_cmd_verify_dir dirname "$0"
    run_cmd_verify_dir realpath "$out"
    MYDIR_PATH="$out"
    # Export CMS_META_TOOLS_PATH environment variable so any other scripts we call
    # can use it, rather than repeating this stuff
    run_cmd_verify_dir realpath "${MYDIR_PATH}/.."
    export CMS_META_TOOLS_PATH="$out"
    info "Exported CMS_META_TOOLS_PATH as '${CMS_META_TOOLS_PATH}'"
# Backup plan is to use BASH_SOURCE, but note that MacOS in particular does not support this
elif [ -n "${BASH_SOURCE[0]}" ]; then
    run_cmd_verify_dir dirname "${BASH_SOURCE[0]}"
    MYDIR_PATH="$out"
    # Export CMS_META_TOOLS_PATH environment variable so any other scripts we call
    # can use it, rather than repeating this stuff
    export CMS_META_TOOLS_PATH="${MYDIR_PATH}/.."
    info "Exported CMS_META_TOOLS_PATH as '${CMS_META_TOOLS_PATH}'"
else
    info "realpath and BASH_SOURCE both unavailable"
    err_exit "Unable to determine path to cms-meta-tools"
fi
[ -f "${MYDIR_PATH}/$MYNAME" ] || err_exit "$MYNAME not found in directory ${MYDIR_PATH}"

FF_PY_NAME=file_filter.py
FF_PY_PATH="${MYDIR_PATH}/${FF_PY_NAME}"
[ -f "${FF_PY_PATH}" ] || err_exit "${FF_PY_NAME} not found in directory ${MYDIR_PATH}"

# Test to see if yaml module is available
. "${CMS_META_TOOLS_PATH}/utils/pyyaml.sh"

# Now call file_filter located in this directory, with same arguments this script was passed
"${MYDIR_PATH}"/file_filter.py "$@"
exit $?

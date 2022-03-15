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
# Very simple scanner for files missing copyrights & licenses
# It should be called from the root of the target repo
# Usage: copyright_license_check.sh

TMPFILE1=/tmp/.copyright_license_check.$$.$RANDOM.tmp.1
TMPFILE2=/tmp/.copyright_license_check.$$.$RANDOM.tmp.2
CLC_CONF="copyright_license_check.yaml"
MYDIR="copyright_license_check"
MYNAME="copyright_license_check.sh"

function info
{
    echo "$MYNAME: $*"
}

function err_exit
{
    info "ERROR: $*" 1>&2
    exit 1
}

function scan_file
{
    local prefix="Copyright[[:space:]]"
    local year="(19|20)[0-9][0-9]"
    echo -n "Scanning $1... "
    # skip empty files
    if [ -s "$1" ]; then
        local -i missing
        missing=0
        echo -n "copyright... "
        if ! grep -Eq "$prefix" "$1" ; then
            echo -n "missing"
            missing=1
        # We allow for the copyright years to be surrounded by brackets, or not
        elif ! grep -Eq "(${prefix}|${prefix}\[)${year}" "$1" ; then
            echo -n "missing year"
            missing=1
        elif ! grep -Eq "(${prefix}|${prefix}\[)${year}.*[[:space:]]Hewlett Packard Enterprise Development LP" "$1" ; then
            echo -n "missing/incorrect company name"
            missing=1
        else
            echo -n "OK"
        fi
        echo -n "; license... "
        if ! grep -q "MIT License" "$1" ; then
            echo "missing"
            missing=1
        else
            echo "OK"
        fi
        return $missing
    fi
    echo "OK"
    return 0
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

info "clc should be located in directory $MYDIR_PATH"

# Default config file should be located in the same directory as this script
DEFAULT_CLC_CONF="${MYDIR_PATH}/${CLC_CONF}"
if [ -s "$DEFAULT_CLC_CONF" ]; then
    info "Located default clc config file: $DEFAULT_CLC_CONF"
else
    if [ -f "$DEFAULT_CLC_CONF" ]; then
        info "File is zero size: $DEFAULT_CLC_CONF"
    elif [ -e "$DEFAULT_CLC_CONF" ]; then
        info "Exists but is not a file: $DEFAULT_CLC_CONF"
    fi
    err_exit "Unable to locate clc directory and/or config file $CLC_CONF"
fi

REPO_CLC_CONF=./$CLC_CONF
if [ -f "$REPO_CLC_CONF" ]; then
    info "Found repo clc config file: $REPO_CLC_CONF"
else
    info "No repo-specific clc config file. Default only will be used."
    REPO_CLC_CONF=""
fi

FF_SH="file_filter.sh"
# file_filter script should be in a sibling directory to this one
FF_DIR="${CMS_META_TOOLS_PATH}/file_filter"
FF_TARGETS="$FF_DIR/$FF_SH"
if [ -x "$FF_TARGETS" ] && [ -s "$FF_TARGETS" ]; then
    info "Located $FF_SH in $FF_DIR"
else
    if [ -x "$FF_TARGETS" ]; then
        err_exit "File is zero size: $FF_TARGETS"
    elif [ -s "$FF_TARGETS" ]; then
        err_exit "File is not executable: $FF_TARGETS"
    elif [ -f "$FF_TARGETS" ]; then
        err_exit "File is zero size and not executable: $FF_TARGETS"
    elif [ -e "$FF_TARGETS" ]; then
        err_exit "Exists but is not a file: $FF_TARGETS"
    elif [ -d "$FF_DIR" ]; then
        err_exit "Does not exist: $FF_TARGETS"
    elif [ -e "$FF_DIR" ]; then
        err_exit "Exists but is not a directory: $FF_DIR"
    fi
    err_exit "Does not exist: $FF_DIR"
fi

if ! git ls-files --empty-directory > $TMPFILE1 ; then
    rm -f $TMPFILE1 >/dev/null 2>&1
    err_exit "Command failed:  git ls-files --empty-directory"
fi

# $REPO_CLC_CONF not in quotes because we know it has no whitespace and because if it is
# blank (meaning there is no repo clc config file), we do not want it passed as an empty
# string argument
if ! cat $TMPFILE1 | "$FF_TARGETS" "$DEFAULT_CLC_CONF" $REPO_CLC_CONF > $TMPFILE2 ; then
    rm -f $TMPFILE1 $TMPFILE2 >/dev/null 2>&1
    err_exit "$FF_TARGETS failed"
fi

FAIL=0

while read FILE ; do
    scan_file "$FILE" || FAIL=1
done << EOF
$(cat $TMPFILE2)
EOF

rm -f $TMPFILE1 $TMPFILE2 >/dev/null 2>&1

if [ $FAIL -eq 0 ]; then
    info "All scanned code passed"
    exit 0
fi

err_exit "Some code is missing proper copyright or license, see list above"

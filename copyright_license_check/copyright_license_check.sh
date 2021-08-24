#!/usr/bin/env bash

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

# Very simple scanner for files missing copyrights & licenses
# It should be called from the root of the target repo
# Usage: copyright_license_check.sh

TMPFILE1=/tmp/.copyright_license_check.$$.$RANDOM.tmp.1
TMPFILE2=/tmp/.copyright_license_check.$$.$RANDOM.tmp.2
CLC_CONF="copyright_license_check.yaml"
MYDIR="copyright_license_check"
MYNAME="copyright_license_check.sh"

function err_exit
{
    echo "$MYNAME: ERROR: $*" 1>&2
    exit 1
}

function scan_file
{
    echo -n "Scanning $1... "
    # skip empty files
    if [ -s "$1" ]; then
        local -i missing
        missing=0
        echo -n "copyright... "
        if ! grep -Eq "Copyright[[:space:]]" "$1" ; then
            echo -n "missing"
            missing=1
        # We allow for the copyright years to be surrounded by brackets, or not
        elif ! grep -Eq "Copyright[[:space:]](|\[)(19|20)[0-9][0-9]" "$1" ; then
            echo -n "missing year"
            missing=1
        elif ! grep -Eq "Copyright[[:space:]](|\[)(19|20)[0-9][0-9].*[[:space:]]Hewlett Packard Enterprise Development LP" "$1" ; then
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

# Default config file should be located in the same directory as this script
# This conditional makes the script more Mac-friendly
if [ -n "${CMS_META_TOOLS_PATH}" ] && [ -f "${CMS_META_TOOLS_PATH}/${MYDIR}/${MYNAME}" ]; then
    echo "CMS_META_TOOLS_PATH is set to $CMS_META_TOOLS_PATH"
    CLC_DIR="${CMS_META_TOOLS_PATH}/${MYDIR}"
elif [ -n "${BASH_SOURCE[0]}" ]; then
    run_cmd_verify_dir dirname "${BASH_SOURCE[0]}"
    CLC_DIR="$out"
    # Export CMS_META_TOOLS_PATH environment variable so any other scripts we call
    # can use it, rather than repeating this stuff
    export CMS_META_TOOLS_PATH="${CLC_DIR}/.."
else
    # MacOS. In this case, try realpath
    run_cmd_verify_dir dirname "$0"
    run_cmd_verify_dir realpath "$out"
    CLC_DIR="$out"
    # Export CMS_META_TOOLS_PATH environment variable so any other scripts we call
    # can use it, rather than repeating this stuff
    export CMS_META_TOOLS_PATH="${CLC_DIR}/.."
fi
[ -f "${CLC_DIR}/$MYNAME" ] || err_exit "$MYNAME not found in directory $CLC_DIR"

echo "clc should be located in directory $CLC_DIR"
DEFAULT_CLC_CONF="$CLC_DIR/$CLC_CONF"
if [ -s "$DEFAULT_CLC_CONF" ]; then
    echo "Located default clc config file: $DEFAULT_CLC_CONF"
else
    if [ -f "$DEFAULT_CLC_CONF" ]; then
        echo "File is zero size: $DEFAULT_CLC_CONF"
    elif [ -e "$DEFAULT_CLC_CONF" ]; then
        echo "Exists but is not a file: $DEFAULT_CLC_CONF"
    fi
    err_exit "Unable to locate clc directory and/or config file $CLC_CONF"
fi

REPO_CLC_CONF=./$CLC_CONF
if [ -f "$REPO_CLC_CONF" ]; then
    echo "Found repo clc config file: $REPO_CLC_CONF"
else
    echo "No repo-specific clc config file. Default only will be used."
    REPO_CLC_CONF=""
fi

FF_SH="file_filter.sh"
# file_filter script should be in a sibling directory to this one
FF_DIR="${CMS_META_TOOLS_PATH}/file_filter"
FF_TARGETS="$FF_DIR/$FF_SH"
if [ -x "$FF_TARGETS" ] && [ -s "$FF_TARGETS" ]; then
    echo "Located $FF_SH in $FF_DIR"
else
    if [ -x "$FF_TARGETS" ]; then
        echo "File is zero size: $FF_TARGETS"
    elif [ -s "$FF_TARGETS" ]; then
        echo "File is not executable: $FF_TARGETS"
    elif [ -f "$FF_TARGETS" ]; then
        echo "File is zero size and not executable: $FF_TARGETS"
    elif [ -e "$FF_TARGETS" ]; then
        echo "Exists but is not a file: $FF_TARGETS"
    elif [ -d "$FF_DIR" ]; then
        echo "Does not exist: $FF_TARGETS"
    elif [ -e "$FF_DIR" ]; then
        echo "Exists but is not a directory: $FF_DIR"
    else
        echo "Does not exist: $FF_DIR"
    fi
    err_exit "Problem with $FF_SH in $FF_DIR directory"
fi

if ! git ls-files --empty-directory > $TMPFILE1 ; then
    echo "ERROR: Command failed:  git ls-files --empty-directory" 1>&2
    rm -f $TMPFILE1 >/dev/null 2>&1
    exit 1
fi

# $REPO_CLC_CONF not in quotes because we know it has no whitespace and because if it is
# blank (meaning there is no repo clc config file), we do not want it passed as an empty
# string argument
if ! cat $TMPFILE1 | "$FF_TARGETS" "$DEFAULT_CLC_CONF" $REPO_CLC_CONF > $TMPFILE2 ; then
    echo "ERROR: $FF_TARGETS failed" 1>&2
    rm -f $TMPFILE1 $TMPFILE2 >/dev/null 2>&1
    exit 1
fi

FAIL=0

while read FILE ; do
    scan_file "$FILE" || FAIL=1
done << EOF
$(cat $TMPFILE2)
EOF

rm -f $TMPFILE1 $TMPFILE2 >/dev/null 2>&1

if [ $FAIL -eq 0 ]; then
    echo "All scanned code passed"
else
    echo "Some code is missing proper copyright or license, see list above" 1>&2
fi

exit $FAIL

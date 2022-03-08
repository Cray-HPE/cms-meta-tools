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
# Very simple scanner for Go files which runs the gofmt linter on them
#
# It should be called from the root of the target repo
# Usage: go_lint.sh

TMPFILE1=/tmp/.go_lint.$$.$RANDOM.tmp.1
TMPFILE2=/tmp/.go_lint.$$.$RANDOM.tmp.2
GL_CONF="go_lint.yaml"
MYDIR="go_lint"
MYNAME="go_lint.sh"

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
    local out
    local rc
    echo -n "Scanning $1 with gofmt... "
    # skip empty files
    if [ -s "$1" ]; then
        out=$(gofmt -s -l "$1")
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "UNEXPECTED ERROR: gofmt exited with return code $rc"
            return 1
        # gofmt return code is 0 regardless of whether or not it finds problems.
        # It outputs nothing if the file is okay, otherwise it outputs the
        # filename. So we check to see if we got any output or not.
        elif [ -n "$out" ]; then
            echo "ERROR"
            return 1
        fi
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

info "go_lint is be located in directory $MYDIR_PATH"

# Default config file should be located in the same directory as this script
DEFAULT_GL_CONF="$MYDIR_PATH/$GL_CONF"
if [ -s "$DEFAULT_GL_CONF" ]; then
    info "Located default gl config file: $DEFAULT_GL_CONF"
else
    if [ -f "$DEFAULT_GL_CONF" ]; then
        info "File is zero size: $DEFAULT_GL_CONF"
    elif [ -e "$DEFAULT_GL_CONF" ]; then
        info "Exists but is not a file: $DEFAULT_GL_CONF"
    fi
    err_exit "Unable to locate gl config file $GL_CONF"
fi

REPO_GL_CONF=./$GL_CONF
if [ -f "$REPO_GL_CONF" ]; then
    info "Found repo gl config file: $REPO_GL_CONF"
else
    info "No repo-specific gl config file. Default only will be used."
    REPO_GL_CONF=""
fi

FF_SH="file_filter.sh"
# file_filter script should be in a sibling directory to this one
FF_DIR="${CMS_META_TOOLS_PATH}/file_filter"
FF_TARGETS="$FF_DIR/$FF_SH"
if [ -x "$FF_TARGETS" ] && [ -s "$FF_TARGETS" ]; then
    info "Located $FF_SH in $FF_DIR"
else
    if [ -x "$FF_TARGETS" ]; then
        info "File is zero size: $FF_TARGETS"
    elif [ -s "$FF_TARGETS" ]; then
        info "File is not executable: $FF_TARGETS"
    elif [ -f "$FF_TARGETS" ]; then
        info "File is zero size and not executable: $FF_TARGETS"
    elif [ -e "$FF_TARGETS" ]; then
        info "Exists but is not a file: $FF_TARGETS"
    elif [ -d "$FF_DIR" ]; then
        info "Does not exist: $FF_TARGETS"
    elif [ -e "$FF_DIR" ]; then
        info "Exists but is not a directory: $FF_DIR"
    else
        info "Does not exist: $FF_DIR"
    fi
    err_exit "Problem with $FF_SH in $FF_DIR directory"
fi

if ! git ls-files --empty-directory > $TMPFILE1 ; then
    rm -f $TMPFILE1 >/dev/null 2>&1
    err_exit "Command failed:  git ls-files --empty-directory"
fi

# $REPO_GL_CONF not in quotes because we know it has no whitespace and because if it is
# blank (meaning there is no repo gl config file), we do not want it passed as an empty
# string argument
if ! cat $TMPFILE1 | "$FF_TARGETS" "$DEFAULT_GL_CONF" $REPO_GL_CONF > $TMPFILE2 ; then
    rm -f $TMPFILE1 $TMPFILE2 >/dev/null 2>&1
    err_exit "$FF_TARGETS failed"
elif [ ! -s "$TMPFILE2" ]; then
    info "No go code found to scan that met the filtering criteria"
    exit 0
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

info "To fix detected errors in a file, run: gofmt -s -l -w <filename>"
err_exit "Some code failed gofmt check, see list above"

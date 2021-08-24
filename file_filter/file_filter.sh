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

MYDIR="file_filter"
MYNAME="file_filter.sh"

function err_exit
{
    echo "$MYNAME: ERROR: $*" 1>&2
    exit 1
}

function info
{
    echo "$MYNAME: $*" 1>&2
}

function run_cmd_verify_dir
{
    out=$("$@") || err_exit "Command failed: $*"
    [ -n "$out" ] || err_exit "Command gave blank outut: $*"
    [ -e "$out" ] || err_exit "Nonexistent path ($out) given by command: $*"
    [ -d "$out" ] || err_exit "Non-directory path ($out) given by command: $*"
}

if [ -n "${CMS_META_TOOLS_PATH}" ] && [ -f "${CMS_META_TOOLS_PATH}/${MYDIR}/${MYNAME}" ]; then
    info "CMS_META_TOOLS_PATH is set to $CMS_META_TOOLS_PATH"
    FF_DIR="${CMS_META_TOOLS_PATH}/${MYDIR}"
elif [ -n "${BASH_SOURCE[0]}" ]; then
    run_cmd_verify_dir dirname "${BASH_SOURCE[0]}"
    FF_DIR="$out"
    # Export CMS_META_TOOLS_PATH environment variable so any other scripts we call
    # can use it, rather than repeating this stuff
    export CMS_META_TOOLS_PATH="${FF_DIR}/.."
else
    # MacOS. In this case, try realpath
    run_cmd_verify_dir dirname "$0"
    run_cmd_verify_dir realpath "$out"
    FF_DIR="$out"
    # Export CMS_META_TOOLS_PATH environment variable so any other scripts we call
    # can use it, rather than repeating this stuff
    export CMS_META_TOOLS_PATH="${FF_DIR}/.."
fi
[ -f "${FF_DIR}/$MYNAME" ] || err_exit "$MYNAME not found in directory $FF_DIR"

# Test to see if yaml module is available
if ! python3 -c "import yaml" 1>&2 ; then
    # In case this is an alpine container
    apk add --no-cache py3-pip python3 > /dev/null 2>&1
    python3 -m ensurepip 1>&2
    pip3 install PyYAML \
        --no-cache-dir \
        --trusted-host dst.us.cray.com \
        --index-url http://dst.us.cray.com/piprepo/simple 1>&2
    if ! python3 -c "import yaml" 1>&2 ; then
        err_exit "Unable to install Python yaml module"
    fi
fi

# Now call file_filter located in this directory, with same arguments this script was passed
"${FF_DIR}"/file_filter.py "$@"
exit $?

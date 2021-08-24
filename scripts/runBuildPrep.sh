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

# Find my directory, so I know where to find my friends
MYDIR="scripts"
MYNAME="runBuildPrep.sh"

function err_exit
{
    echo "$MYNAME: ERROR: $*" 1>&2
    exit 1
}

function run_cmd_exit
{
    "$@" || err_exit "Command failed: $*"
}

function run_cmd_verify_dir
{
    out=$("$@") || err_exit "Command failed: $*"
    [ -n "$out" ] || err_exit "Command gave blank outut: $*"
    [ -e "$out" ] || err_exit "Nonexistent path ($out) given by command: $*"
    [ -d "$out" ] || err_exit "Non-directory path ($out) given by command: $*"
}

if [ -n "${CMS_META_TOOLS_PATH}" ] && [ -f "${CMS_META_TOOLS_PATH}/${MYDIR}/${MYNAME}" ]; then
    echo "CMS_META_TOOLS_PATH is set to $CMS_META_TOOLS_PATH"
elif [ -n "${BASH_SOURCE[0]}" ]; then
    run_cmd_verify_dir dirname "${BASH_SOURCE[0]}"
    # Export CMS_META_TOOLS_PATH environment variable so any other scripts we call
    # can use it, rather than repeating this stuff
    export CMS_META_TOOLS_PATH="${out}/.."
    echo "Setting CMS_META_TOOLS_PATH to $CMS_META_TOOLS_PATH (used BASH_SOURCE[0])"
else
    # MacOS. In this case, try realpath
    run_cmd_verify_dir dirname "$0"
    run_cmd_verify_dir realpath "$out"
    # Export CMS_META_TOOLS_PATH environment variable so any other scripts we call
    # can use it, rather than repeating this stuff
    export CMS_META_TOOLS_PATH="${out}/.."
    echo "Setting CMS_META_TOOLS_PATH to $CMS_META_TOOLS_PATH (used realpath)"
fi

# If there is no external version conf file, the script will exit with exit code 0
# If this script fails, we do not want to proceed to updating versions, since it likely
# relies on this one having worked
run_cmd_exit "${CMS_META_TOOLS_PATH}/latest_version/update_external_versions.sh"

# If there is no version conf file, the script will exit with exit code 0
run_cmd_exit "${CMS_META_TOOLS_PATH}/update_versions/update_versions.sh"

# If there is no git_info.conf file, the script will exit with exit code 0
run_cmd_exit "${CMS_META_TOOLS_PATH}/git_info/git_info.sh"

exit 0

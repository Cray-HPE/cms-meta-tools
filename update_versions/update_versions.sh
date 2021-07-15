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

# This script replaces version tags in source files with the actual version number,
# based on what is listed in $CONFIGFILE. If that file does not exist, nothing is updated.
# This script should be run from the root of the target repo.
#
# $CONFIGFILE is parsed from top to bottom. Whenever a line beginning with "targetfile:" is
# found, the file that follows has its version tags replaced with the actual version string.
# If not specified, the version tag and actual version source file take the default values
# specified above. They can be specified in the config file with "tag:" and "sourcefile:"
# lines. Such lines apply unless/until a later line overrides their values.
#
# Lines in the config file that do not begin with "sourcefile:", "tag:", or "targetfile:" are
# ignored.

# Version must be of the form #.#.# where unnecessary leading 0s are not allowed
VPATTERN="^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$"
CONFIGFILE="update_versions.conf"
DEFAULT_VERSION_SOURCEFILE=".version"
DEFAULT_VERSION_TAG="@VERSION@"

function error_exit
{
    echo "ERROR: $*"
    exit 1
}

function run_cmd
{
    "$@" || error_exit "Command failed with rc $?: $*"
    return 0
}

function process_file
{
    # $1 - file
    # $2 - tag
    # $3 - string
    [ $# -eq 3 ] || 
        error_exit "PROGRAMMING LOGIC ERROR: process_file should get exactly 3 arguments but it received $#: $*"
    F="$1"
    VTAG="$2"
    VSTRING="$3"
    echo "Replacing version tags ($VTAG) in $F"
    grep -q "$VTAG" "$F" ||
        error_exit "Version tag ($VTAG) not found in file $F"
    BEFORE="${F}.before"
    run_cmd cp "$F" "$BEFORE"
    run_cmd sed -i s/${VTAG}/${VSTRING}/g "$F"
    echo "# diff \"$BEFORE\" \"$F\""
    diff "$BEFORE" "$F"
    rc=$?
    if [ $rc -eq 0 ]; then
        error_exit "diff reports no difference after tag replacement"
    elif [ $rc -ne 1 ]; then
        error_exit "diff encountered an error comparing the files"
    fi
    run_cmd rm "$BEFORE"
    return 0
}

function update_tags
{
    local tag sourcefile targetfile versionstring
    # Set defaults
    tag="$DEFAULT_VERSION_TAG"
    sourcefile="$DEFAULT_VERSION_SOURCEFILE"
    versionstring=""
    while read vars; do
        if [[ "$vars" =~ ^tag: ]]; then
            tag=$(echo $vars | sed -e 's/^tag:[[:space:]]*//' -e 's/[[:space:]]*$//')
        elif [[ "$vars" =~ ^sourcefile ]]; then
            sourcefile=$(echo $vars | sed -e 's/^sourcefile:[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -e "$sourcefile" ] ||
                error_exit "sourcefile ($sourcefile) specified in $CONFIGFILE does not exist"
            # Whenever we see a new sourcefile variable we need to invalidate our previous version string
            versionstring=""
        elif [[ "$vars" =~ ^targetfile ]]; then
            targetfile=$(echo $vars | sed -e 's/^targetfile:[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -e "$targetfile" ] ||
                error_exit "targetfile ($targetfile) specified in $CONFIGFILE does not exist"
            # Process this file
            if [ -z "$versionstring" ]; then
                echo "Reading version string from $sourcefile"
                versionstring=$(cat "$sourcefile") ||
                    error_exit "Failed: cat $sourcefile"
                echo "Version string from $sourcefile is \"$versionstring\""
                [[ $versionstring =~ $VPATTERN ]] ||
                    error_exit "Version string does not match expected format"
            fi
            process_file "$targetfile" "$tag" "$versionstring"
        else
            # Should never see this, based on the grep command we run on $CONFIGFILE
            error_exit "PROGRAMMING LOGIC ERROR: Unexpected value of vars = $vars"
        fi
    done <<-EOF
	$(grep -E '^(tag|sourcefile|targetfile):' $CONFIGFILE)
	EOF
    return 0
}

if [ ! -e "$CONFIGFILE" ]; then
    echo "$CONFIGFILE does not exist -- nothing to do"
    exit 0
fi
update_tags
exit 0

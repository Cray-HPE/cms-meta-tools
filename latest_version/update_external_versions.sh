#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2023 Hewlett Packard Enterprise Development LP
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
# This script reads what is in the update_external_versions.conf file, and based on
# what is there, finds the latest version of images and writes that version to a file.
# Typically this file is one that is specified in an update_versions.conf file.
#
# $CONFIGFILE is parsed from top to bottom, and is broken up into stanzas for each image.
# The stanza begins with an image field and ends when either another image field or the end
# of the file is reached. At the end of each stanza, the latest version of the image is
# determined and written to a file. See the update_external_versions.conf.template file
# for details on what fields may appear in a stanza and what effect they have.
#
# Lines in the config file which do not set one of the recognized fields are ignored.
#
# Note that this script does not actually do any of the work of finding the latest version.
# It is merely a fancy wrapper to the latest_version.sh script. Additionally, this script
# should not be assumed to do any error checking or validation on the values being read in
# from the config file and passed into the latest_version script. Such checking and validation
# are done by the latest_version.sh script.
#
# This script always calls the latest_version script with the --overwrite flag

CONFIGFILE="update_external_versions.conf"
LVBASE="latest_version.sh"
MYDIR="latest_version"
MYNAME="update_external_versions.sh"

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

function run_cmd
{
    "$@" || err_exit "Command failed with rc $?: $*"
    return 0
}

function run_lvscript
{
    if "$LVSCRIPT" "$@" ; then
        info "Success: $LVSCRIPT $*"
        return 0
    fi
    err_exit "Failed: $LVSCRIPT $*"
}

function update_tags
{
    local image lv_args
    image=""
    # We always include the overwrite argument
    lv_args=("--overwrite")
    while read vars; do
        field_name=$(echo "$vars" | cut -d":" -f1)
        field_value=$(echo "$vars" | cut -d":" -f2-)
        if [ "$field_name" != image ] && [ -z "$image" ]; then
            # If image is not set, we should not be seeing any other fields
            err_exit "Line in $CONFIGFILE is not part of an image stanza: $vars"
        fi
        case "$field_name" in
            "image")
                # If we have an image name currently set, then
                # this means it is time to process it
                if [ -n "$image" ]; then
                    run_lvscript "${lv_args[@]}"  "$image"
                fi
                # Set new image name, reset latest_version args, if any
                image="$field_value"
                # We always include the overwrite argument
                lv_args=("--overwrite")
                ;;
            "source")
                if [ "$field_value" = docker ] || [ "$field_value" = helm ] || [ "$field_value" = python ]; then
                    lv_args+=("--$field_value")
                else
                    err_exit "Source field may only be set to docker, helm, or python. Invalid value: $field_value"
                fi
                ;;
            *)
                # For all other fields (major, minor, outfile, server, team, type, and url) the
                # argument name is the same as the field name, so it's easy
                lv_args+=("--$field_name" "$field_value")
                ;;
        esac
    done <<-EOF
    $(grep -E '^[[:space:]]*(image|major|minor|outfile|server|source|team|type|url):' $CONFIGFILE |
        sed -e 's/^[[:space:]][[:space:]]*//' \
            -e 's/[[:space:]][[:space:]]*$//' \
            -e 's/^\([^:][^:]*\):[[:space:]][[:space:]]*/\1:/')
EOF
    # The above grep/sed commands grab all of the lines with fields, strip off the whitespace
    # at the beginning of the line, end of the line, and between the : and the field value

    # When we get here, unless the config file was empty, image will be set with one final stanza
    # to be processed
    if [ -n "$image" ]; then
        run_lvscript "${lv_args[@]}"  "$image"
    fi
    return 0
}

# We should be running from the root of the target repo, so the config file should
# be found in this directory
if [ ! -e "$CONFIGFILE" ]; then
    info "$CONFIGFILE does not exist -- nothing to do"
    exit 0
fi

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

LVSCRIPT="${MYDIR_PATH}/${LVBASE}"

if [ ! -x "$LVSCRIPT" ]; then
    err_exit "$LVSCRIPT file exists but is not executable"
fi

update_tags
exit 0

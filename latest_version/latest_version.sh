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
USAGE="\
usage: latest_version.sh [--major x [--minor y]]
                         [--docker | --helm] [--type <type>]
                         [[--server <server>] [--team <team>]  | [--url <url>]]
                         [--outfile <file> [--overwrite]] image_name
       latest_version.sh {-h || --help}"

USAGE_EXTRA="\
server: algol60 or arti. Defaults to algol60 (unless url is specified, in which case it is not used)
team: Defaults to csm (unless url is specified, in which case it is not used)
type: Defaults to stable (unless url is specified, in which case it may still be specified but has no
default value if it is not specified)

For server arti:
docker: use https://arti.dev.cray.com/artifactory/<team>-docker-<type>-local/repository.catalog
helm: use https://arti.dev.cray.com/artifactory/<team>-helm-<type>-local/index.yaml

For server algol60:
docker: use https://artifactory.algol60.net/artifactory/<team>-docker/repository.catalog
helm: use https://artifactory.algol60.net/artifactory/<team>-helm-charts/index.yaml

For url, the file at the specified URL will be used.
docker: Assumes file is in the same JSON format as the arti/algol60 repository.catalog files
helm: Assumes file is in the same YAML format as the arti/algol60 index.yaml files

Looks in file for newest version of specified image name, and returns the version string.
If a major is specified, it confines itself to versions of that major number.
If a minor is also specified, it further confines itself to versions of that minor number.
Major and minor numbers must be nonnegative integers and may not have leading 0s
For algol60, the type field is used within these files to distinguish between
stable and unstable images by looking at the path to the images.

Version is written to either the specified outfile or <image_name>.version if no outfile is specified.
If the output file already exists, the script exits in error unless --overwrite is specified."

MYDIR="latest_version"
MYNAME="latest_version.sh"

function usage
{
    echo "$USAGE" 1>&2
    echo
    if [ $# -eq 0 ]; then
        echo "$USAGE_EXTRA" 1>&2
        exit 0
    fi
    while [ $# -gt 0 ]; do
        echo "ERROR: $1" 1>&2
        shift
    done
    exit 1
}

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

IMAGE_NAME=""
MAJOR=""
MINOR=""
TEAM=""
TYPE=""
DOCKER_HELM=""
OUTFILE=""
OVERWRITE=N
SERVER=""
URL=""

function parse_arguments
{
    while [ $# -gt 0 ]; do
        case "$1" in
            "--docker"|"--helm")
                [ -n "$DOCKER_HELM" ] && usage "--docker and --helm must be specified no more than once total"
                DOCKER_HELM=$(echo "$1" | sed 's/^[-][-]//')
                shift
                ;;
            "--major")
                [ -n "$MAJOR" ] && usage "--major may not be specified multiple times"
                [ $# -lt 2 ] && usage "--major requires an argument"
                echo "$2" | grep -Eq "^(0|[1-9][0-9]*)$" || usage "Invalid major number: $2"
                MAJOR="$2"
                shift 2
                ;;
            "--minor")
                [ -n "$MINOR" ] && usage "--minor may not be specified multiple times"
                [ $# -lt 2 ] && usage "--minor requires an argument"
                echo "$2" | grep -Eq "^(0|[1-9][0-9]*)$" || usage "Invalid minor number: $2"
                MINOR="$2"
                shift 2
                ;;
            "--outfile")
                [ -n "$OUTFILE" ] && usage "--outfile may not be specified multiple times"
                [ $# -lt 2 ] && usage "--outfile requires an argument"
                [ -z "$2" ] && usage "Output file may not be blank"
                [ -e "$2" ] && [ ! -f "$2" ] && usage "Output file already exists and is not a regular file: $2"
                OUTFILE="$2"
                shift 2
                ;;
            "--overwrite")
                [ "$OVERWRITE" = Y ] && usage "--overwrite may not be specified multiple times"
                OVERWRITE=Y
                shift
                ;;
            "--server")
                [ -n "$SERVER" ] && usage "--server may not be specified multiple times"
                [ -n "$URL" ] && usage "--server and --url are mutually exclusive"
                [ $# -lt 2 ] && usage "--server requires an argument"
                [ -z "$2" ] && usage "Server may not be blank"
                if [ "$2" != "arti" ] && [ "$2" != "algol60" ]; then
                    usage "--server argument must be arti or algol60. Invalid server: $2"
                fi
                SERVER="$2"
                shift 2
                ;;
            "--team")
                [ -n "$TEAM" ] && usage "--team may not be specified multiple times"
                [ -n "$URL" ] && usage "--team and --url are mutually exclusive"
                [ $# -lt 2 ] && usage "--team requires an argument"
                [ -z "$2" ] && usage "Team may not be blank"
                echo "$2" | grep -Eq "[^-_.a-zA-Z0-9]" && usage "Invalid characters in team name: $2"
                TEAM="$2"
                shift 2
                ;;
            "--type")
                [ -n "$TYPE" ] && usage "--type may not be specified multiple times"
                [ $# -lt 2 ] && usage "--type requires an argument"
                [ -z "$2" ] && usage "Type may not be blank"
                echo "$2" | grep -Eq "[^-_.a-zA-Z0-9]" && usage "Invalid characters in type name: $2"
                TYPE="$2"
                shift 2
                ;;
            "--url")
                [ -n "$URL" ] && usage "--url may not be specified multiple times"
                [ -n "$SERVER" ] && usage "--server and --url are mutually exclusive"
                [ -n "$TEAM" ] && usage "--team and --url are mutually exclusive"
                [ $# -lt 2 ] && usage "--url requires an argument"
                [ -z "$2" ] && usage "URL may not be blank"
                URL="$2"
                shift 2
                ;;
            *)
                # Must be our image name
                [ -z "$1" ] && usage "Image name may not be blank"
                echo "$1" | grep -Eq "[^-_.a-zA-Z0-9]" && usage "Invalid characters in image name: $1"
                IMAGE_NAME="$1"
                shift
                [ $# -eq 0 ] || usage "Extra arguments found beyond image name: $*"
                ;;
        esac
    done
    [ -z "$IMAGE_NAME" ] && usage "Image name must be specified"
    [ -z "$DOCKER_HELM" ] && DOCKER_HELM="docker"
    [ -n "$MINOR" ] && [ -z "$MAJOR" ] && usage "--minor may not be specified without --major"
    [ -z "$OUTFILE" ] && OUTFILE="${IMAGE_NAME}.version"
    if [ -e "$OUTFILE" ]; then
        if [ ! -f "$OUTFILE" ]; then
            usage "Output file $OUTFILE already exists but is not a regular file"
        elif [ "$OVERWRITE" = Y ]; then
            echo "$OUTFILE already exists and will be overwritten (--overwrite specified)" 1>&2
        else
            usage "Output file $OUTFILE already exists, and --overwrite not specified"
        fi
    fi
    # If URL is not specified, then set default values for TEAM, TYPE, and SERVER
    if [ -z "$URL" ]; then
        [ -z "$TEAM" ] && TEAM="csm"
        [ -z "$TYPE" ] && TYPE="stable"
        [ -z "$SERVER" ] && SERVER="algol60"
    fi
}

parse_arguments "$@"
if [ -z "$URL" ]; then
    if [ "$SERVER" = "arti" ]; then
        URL="https://arti.dev.cray.com/artifactory/${TEAM}-${DOCKER_HELM}-${TYPE}-local"
        if [ "${DOCKER_HELM}" = helm ]; then
            URL="$URL/index.yaml"
        else
            URL="$URL/repository.catalog"
        fi
    else
        # algol60
        URL="https://artifactory.algol60.net/artifactory/${TEAM}-"
        if [ "${DOCKER_HELM}" = helm ]; then
            URL="${URL}helm-charts/index.yaml"
        else
            URL="${URL}docker/repository.catalog"
        fi
    fi
fi

if [ "${DOCKER_HELM}" = helm ]; then
    # Test to see if yaml module is available
    . "${CMS_META_TOOLS_PATH}/utils/pyyaml.sh"
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.index.yaml"
else
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.repository.catalog.json"
fi

echo "latest_version.sh: url=$URL" 1>&2

if ! curl -sSf -o "$TMPFILE" "$URL" 1>&2 ; then
    err_exit "Command failed: curl -sSf -o $TMPFILE $URL"
fi

# Construct our list of optional arguments to latest_version.py
OPTIONAL_ARGS=""

# Even if it is set, we do not pass in the type argument if we are
# using arti, because for arti the type is baked into the URL itself
if [ -n "$TYPE" ] && [ "$SERVER" != "arti" ]; then
    OPTIONAL_ARGS="${OPTIONAL_ARGS} --type $TYPE"
fi
if [ -n "$MAJOR" ]; then
    OPTIONAL_ARGS="${OPTIONAL_ARGS} --major $MAJOR"
    if [ -n "$MINOR" ]; then
        OPTIONAL_ARGS="${OPTIONAL_ARGS} --minor $MINOR"
    fi
fi

# Now call latest_version.py located in this directory
UEV=$("$MYDIR_PATH/latest_version.py" "--${DOCKER_HELM}" --file "$TMPFILE" --image "${IMAGE_NAME}" ${OPTIONAL_ARGS}) || exit 1
info "Found version ${UEV} of ${IMAGE_NAME}"
echo "$UEV" > $OUTFILE && exit 0
err_exit "Error writing to $OUTFILE"

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

function usage
{
    echo "$USAGE"
    echo
    if [ $# -eq 0 ]; then
        echo "$USAGE_EXTRA"
        exit 0
    fi
    while [ $# -gt 0 ]; do
        echo "ERROR: $1" 1>&2
        shift
    done
    exit 1
}

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

function get_python_yaml
{
    # Test to see if yaml module is available
    echo "Testing to see if Python yaml module is present" 1>&2
    if ! python3 -c "import yaml" ; then
        # In case this is an alpine container
        echo "Python yaml module not found -- trying to get it" 1>&2
        apk add --no-cache py3-pip python3 > /dev/null 2>&1
        python3 -m ensurepip
        pip3 install PyYAML \
            --no-cache-dir \
            --trusted-host dst.us.cray.com \
            --index-url http://dst.us.cray.com/piprepo/simple
        if ! python3 -c "import yaml" ; then
            echo "ERROR: Unable to install Python yaml module" 1>&2
            exit 1
        fi
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
    get_python_yaml 1>&2
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.index.yaml"
else
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.repository.catalog.json"
fi

echo "latest_version.sh: url=$URL" 1>&2

if ! curl -sSf -o "$TMPFILE" "$URL" 1>&2 ; then
    echo "ERROR: Command failed: curl -sSf -o $TMPFILE $URL" 1>&2
    exit 1
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

MYDIR=$(dirname ${BASH_SOURCE[0]})

# Now call latest_version.py located in this directory
UEV=$($MYDIR/latest_version.py "--${DOCKER_HELM}" --file "$TMPFILE" --image "${IMAGE_NAME}" ${OPTIONAL_ARGS}) || exit 1
echo "Found version ${UEV} of ${IMAGE_NAME}" 1>&2
echo "$UEV" > $OUTFILE && exit 0
echo "ERROR: Error writing to $OUTFILE" 1>&2
exit 1

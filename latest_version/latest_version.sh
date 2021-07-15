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
usage: latest_version.sh [{--docker | --helm}] [--team <team>] [--type <type>]
                         [--major x [--minor y]] [--outfile <file> [--overwrite]] image_name
       latest_version.sh {-h || --help}"

USAGE_EXTRA="\
team: defaults to csm
type: defaults to stable

If docker is specified, grabs https://arti.dev.cray.com/artifactory/<team>-docker-<type>-local/repository.catalog
If helm is specified, grabs https://arti.dev.cray.com/artifactory/<team>-helm-<type>-local/index.yaml
If neither is specified, docker is assumed.

Looks in file for newest version of specified image name, and returns the version string
If a major is specified, it confines itself to versions of that major number.
If a minor is also specified, it further confines itself to versions of that minor number.
Major and minor numbers must be nonnegative integers and may not have leading 0s

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
            "--team")
                [ -n "$TEAM" ] && usage "--team may not be specified multiple times"
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
    # Set defaults
    [ -z "$TEAM" ] && TEAM="csm"
    [ -z "$TYPE" ] && TYPE="stable"
}

function get_python_yaml
{
    # Test to see if yaml module is available
    if ! python3 -c "import yaml" ; then
        # In case this is an alpine container
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
URL="https://arti.dev.cray.com/artifactory/${TEAM}-${DOCKER_HELM}-${TYPE}-local"
if [ "${DOCKER_HELM}" = helm ]; then
    get_python_yaml 1>&2
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.index.yaml"
    URL="$URL/index.yaml"
else
    URL="$URL/repository.catalog"
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.repository.catalog.json"
fi

echo "latest_version.sh: url=$URL" 1>&2

if ! curl -sSf -o "$TMPFILE" "$URL" 1>&2 ; then
    echo "ERROR: Command failed: curl -sSf -o $TMPFILE $URL" 1>&2
    exit 1
fi

MYDIR=$(dirname ${BASH_SOURCE[0]})

# Now call latest_version.py located in this directory
$MYDIR/latest_version.py "${DOCKER_HELM}" "$TMPFILE" "${IMAGE_NAME}" $MAJOR $MINOR > $OUTFILE
exit $?

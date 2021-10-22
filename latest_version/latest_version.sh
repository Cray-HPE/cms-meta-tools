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
usage: latest_version.sh [--major x [--minor y]]
                         --rpm 
                         [--server <server>] [--type <type>] [--uri <uri>] 
                         [--outfile <file> [--overwrite]] rpm_name
usage: latest_version.sh [--major x [--minor y]]
                         --rpm 
                         [--url <url>] 
                         [--outfile <file> [--overwrite]] rpm_name
       latest_version.sh {-h || --help}"

USAGE_EXTRA="\
Looks in file for newest version of specified image or RPM, and returns the version string.
If a major is specified, it confines itself to versions of that major number.
If a minor is also specified, it further confines itself to versions of that minor number.
Major and minor numbers must be nonnegative integers and may not have leading 0s

Version is written to either the specified outfile or <image_name>.version if no outfile is specified.
If the output file already exists, the script exits in error unless --overwrite is specified.

For docker/helm:

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

For algol60, the type field is used within these files to distinguish between
stable and unstable images by looking at the path to the images.

For RPMs:

server: algol60 or custom URL. Defaults to algol60.
type: If server is algol60, defaults to stable. If server is custom URL, type is not a valid argument.
uri: If server is not algol60, this is not a valid argument.

For server algol60, tool looks for RPMs in: https://artifactory.algol60.net/artifactory/csm-rpms/hpe/<type>/<uri>/
Otherwise it will look for the RPMs at the custom URL that is specified."

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
DOCKER_HELM_RPM=""
OUTFILE=""
OVERWRITE=N
SERVER=""
URL=""
URI=""
URLFILE=""
NAMEFILE=""
ARCH=""
ARCHSTRIP=""

function check_outputfile
{
    local FILE
    FILE="$1"
    # If no output file is specified, nothing to check
    [ -z "$FILE" ] && return 0
    # If the specified output file does not exist, we're good
    [ -e "$FILE" ] || return 0
    # If the specified output file exists and is not a regular file, that is bad
    [ -f "$FILE" ] || usage "Output file $FILE already exists and is not a regular file"
    # Finally, since the file exists, make sure overwrite is set
    [ "$OVERWRITE" = Y ] && info "$FILE already exists and will be overwritten (--overwrite specified)" && return 0
    usage "Output file $FILE already exists, and --overwrite not specified"
}

function parse_arguments
{
    local FILE

    while [ $# -gt 0 ]; do
        case "$1" in
            "--docker"|"--helm"|"--rpm")
                [ -n "$DOCKER_HELM_RPM" ] && usage "--docker/--helm/--rpm must be specified no more than once total"
                DOCKER_HELM_RPM=$(echo "$1" | sed 's/^[-][-]//')
                shift
                ;;
            "--arch")
                [ -n "$ARCH" ] && usage "--arch may not be specified multiple times"
                [ $# -lt 2 ] && usage "--arch requires an argument"
                [ -z "$2" ] && usage "Arch may not be blank"
                echo "$2" | grep -Eq "[^-_.a-zA-Z0-9]" && usage "Invalid characters in arch: $2"
                ARCH="$2"
                shift 2
                ;;
            "--archstrip")
                [ -n "$ARCHSTRIP" ] && usage "--archstrip may not be specified multiple times"
                [ $# -lt 2 ] && usage "--archstrip requires an argument"
                [ -z "$2" ] && usage "Archstrip argument may not be blank"
                echo "$2" | grep -Eiq "^(true|false)$" && usage "--archstrip must be true or false. Invalid archstrip argument: $2"
                ARCHSTRIP="$(echo $2 | tr 'A-Z' 'a-z')"
                shift 2
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
            "--namefile")
                [ -n "$NAMEFILE" ] && usage "--namefile may not be specified multiple times"
                [ $# -lt 2 ] && usage "--namefile requires an argument"
                [ -z "$2" ] && usage "Output RPM name file may not be blank"
                NAMEFILE="$2"
                shift 2
                ;;
            "--outfile")
                [ -n "$OUTFILE" ] && usage "--outfile may not be specified multiple times"
                [ $# -lt 2 ] && usage "--outfile requires an argument"
                [ -z "$2" ] && usage "Output file may not be blank"
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
                [ $# -lt 2 ] && usage "--server requires an argument"
                [ -z "$2" ] && usage "Server may not be blank"
                SERVER="$2"
                shift 2
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
            "--uri")
                [ -n "$URI" ] && usage "--uri may not be specified multiple times"
                [ $# -lt 2 ] && usage "--uri requires an argument"
                [ -z "$2" ] && usage "URI may not be blank"
                URI="$2"
                shift 2
                ;;
            "--url")
                [ -n "$URL" ] && usage "--url may not be specified multiple times"
                [ $# -lt 2 ] && usage "--url requires an argument"
                [ -z "$2" ] && usage "URL may not be blank"
                URL="$2"
                shift 2
                ;;
            "--urlfile")
                [ -n "$URLFILE" ] && usage "--urlfile may not be specified multiple times"
                [ $# -lt 2 ] && usage "--urlfile requires an argument"
                [ -z "$2" ] && usage "Output RPM url file may not be blank"
                URLFILE="$2"
                shift 2
                ;;
            *)
                # Must be our image name
                [ -z "$1" ] && usage "Image/RPM name may not be blank"
                echo "$1" | grep -Eq "[^-_.a-zA-Z0-9]" && usage "Invalid characters in image/RPM name: $1"
                IMAGE_NAME="$1"
                shift
                [ $# -eq 0 ] || usage "Extra arguments found beyond image name: $*"
                ;;
        esac
    done
    [ -n "$SERVER" ] && [ -n "$URL" ] && usage "--server and --url are mutually exclusive"
    [ -z "$IMAGE_NAME" ] && 
        usage "Image name must be specified"
    [ -z "$DOCKER_HELM_RPM" ] && DOCKER_HELM_RPM="docker"
    [ -n "$MINOR" ] && [ -z "$MAJOR" ] && 
        usage "--minor may not be specified without --major"
    [ -z "$OUTFILE" ] && OUTFILE="${IMAGE_NAME}.version"
    check_outputfile "$OUTFILE"
    if [ -z "$URL" ]; then
        [ -z "$TYPE" ] && TYPE="stable"
        [ -z "$SERVER" ] && SERVER="algol60"
    fi
    case "$DOCKER_HELM_RPM" in
        "docker"|"helm")
            [ -n "$TEAM" ] && [ -n "$URL" ] && usage "--team and --url are mutually exclusive"
            [ -n "$NAMEFILE" ] && usage "--namefile is not valid with $DOCKER_HELM_RPM"
            [ -n "$ARCH" ] && usage "--arch is not valid with $DOCKER_HELM_RPM"
            [ -n "$ARCHSTRIP" ] && usage "--archstrip is not valid with $DOCKER_HELM_RPM"
            [ -n "$URI" ] && usage "--uri is not valid with $DOCKER_HELM_RPM"
            [ -n "$URLFILE" ] && usage "--urlfile is not valid with $DOCKER_HELM_RPM"
            [ "$SERVER" != "arti" ] && [ "$SERVER" != "algol60" ] &&
                usage "For docker and helm, --server argument must be arti or algol60. Invalid server: $2"
            # If URL is not specified, then set default values for TEAM, TYPE, and SERVER
            if [ -z "$URL" ]; then
                [ -z "$TEAM" ] && TEAM="csm"
                [ -z "$TYPE" ] && TYPE="stable"
                [ -z "$SERVER" ] && SERVER="algol60"
            fi
            ;;
        "rpm")
            [ "$ARCHSTRIP" = false ] && [ -n "$ARCH" ] && usage "If --archstrip is false, --arch may not be used"
            [ -z "$ARCHSTRIP" ] && ARCHSTRIP=true
            [ -n "$URI" ] && [ -n "$URL" ] && usage "--uri and --url are mutually exclusive"
            [ -n "$TEAM" ] && usage "--team is not valid with --rpm"
            [ -n "$SERVER" ] && [ "$SERVER" != algol60 ] && 
                usage "For rpm, if --server is specified, its argument must be algol60"
            [ -n "$URL" ] && [ -n "$TYPE" ] && 
                usage "For rpm, --url and --type are mutually exclusive"
            check_outputfile "$NAMEFILE"
            check_outputfile "$URLFILE"
            ;;
    esac
}

parse_arguments "$@"
if [ -z "$URL" ]; then
    if [ "${DOCKER_HELM_RPM}" = rpm ]; then
        URL="https://artifactory.algol60.net/artifactory/csm-rpms/hpe/${TYPE}/${URI}/"
    elif [ "$SERVER" = "arti" ]; then
        URL="https://arti.dev.cray.com/artifactory/${TEAM}-${DOCKER_HELM_RPM}-${TYPE}-local"
        if [ "${DOCKER_HELM_RPM}" = helm ]; then
            URL="$URL/index.yaml"
        else
            URL="$URL/repository.catalog"
        fi
    else
        # algol60
        URL="https://artifactory.algol60.net/artifactory/${TEAM}-"
        if [ "${DOCKER_HELM_RPM}" = helm ]; then
            URL="${URL}helm-charts/index.yaml"
        else
            URL="${URL}docker/repository.catalog"
        fi
    fi
fi
# Remove redundant // from URL
URL=$(echo "$URL" | sed 's#\([^:/]\)///*#\1/#g')

if [ "${DOCKER_HELM_RPM}" = helm ]; then
    # Test to see if yaml module is available
    . "${CMS_META_TOOLS_PATH}/utils/pyyaml.sh"
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.index.yaml"
elif [ "${DOCKER_HELM_RPM}" = rpm ]; then
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.rpms.txt"
else
    TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.repository.catalog.json"
fi

echo "latest_version.sh: url=$URL" 1>&2

if ! curl -sSf -o "$TMPFILE" "$URL" 1>&2 ; then
    err_exit "Command failed: curl -sSf -o $TMPFILE $URL"
fi

# Construct our list of optional arguments to latest_version.py
OPTIONAL_ARGS=""

if [ -n "$MAJOR" ]; then
    OPTIONAL_ARGS="${OPTIONAL_ARGS} --major $MAJOR"
    if [ -n "$MINOR" ]; then
        OPTIONAL_ARGS="${OPTIONAL_ARGS} --minor $MINOR"
    fi
fi

if [ "${DOCKER_HELM_RPM}" = rpm ]; then
    # If archstrip is true and arch is not set, set arch to the final directory in the URL
    [ "$ARCHSTRIP" = true ] && [ -z "$ARCH" ] && ARCH=$(echo "$URL" | sed 's#//*$##' | awk -F/ '{ print $NF }') && info "arch defaulting to $ARCH"

    if [ -n "$NAMEFILE" ]; then
        OPTIONAL_ARGS="${OPTIONAL_ARGS} --rpm-name-outfile $NAMEFILE"
    elif [ -n "$URLFILE" ]; then
        # The Python tool only knows names, not URLs, so we have to get a name from it and build the URL ourselves
        OPTIONAL_ARGS="${OPTIONAL_ARGS} --rpm-name-outfile $URLFILE"
    fi

    # For RPMs, we do some pre-processing of our input file to filter for our desired RPMs
    # Our desired file format is <semver> <rpm filename>

    # Version must be legal SemVer 2.0 pattern (see semver.org)

    # For all of these below specifications, note that a 0 by itself is not considered to be a leading 0
    NUM_PATTERN="0|[1-9][0-9]*"

    # The basic pattern is 3 nonnegative integers without leading 0s, separated by dots
    BASE_VPATTERN="(${NUM_PATTERN})[.](${NUM_PATTERN})[.](${NUM_PATTERN})"

    # A pre-release identifier is any of the following:
    # - Any string of 1 or more digits with no leading 0s
    # - Any string consisting of 1 or more alphanumeric characters or hyphens, with at least 1 non-numeric character
    PID_PATTERN="(${NUM_PATTERN}|[-a-zA-Z0-9]*[-a-zA-Z][-a-zA-Z0-9]*)"

    # A pre-release version is one or more dot-separated pre-release identifiers
    PRV_PATTERN="${PID_PATTERN}([.]${PID_PATTERN})*"

    # A build identifier is any of the following:
    # - Any string consisting of 1 or more alphanumeric characters or hyphens
    BID_PATTERN="[-a-zA-Z0-9][-a-zA-Z0-9]*"

    # Build metadata is one or more dot-separated build identifiers
    BMD_PATTERN="${BID_PATTERN}([.]${BID_PATTERN})*"

    # The full version string must begin with the base pattern
    # After that is an optional hyphen and pre-release version
    # After those is an optional plus and build-metadata
    VPATTERN="${BASE_VPATTERN}(-${PRV_PATTERN})?([+]${BMD_PATTERN})?"

    # Grab all href targets beginning with <image name>-<semver> ending with .rpm" or .<arch>.rpm"
    # Filter out the href=""
    # Sort and remove any duplicates
    # Then perform sed magic to get our desired file format
    RPM_PREFIX_PATTERN="${IMAGE_NAME}-${VPATTERN}"
    RPM_PATTERN="[hH][rR][eE][fF]=[\"]${RPM_PREFIX_PATTERN}[^\"]*"
    [ "$ARCHSTRIP" = true ] && RPM_PATTERN="${RPM_PATTERN}[.]${ARCH}"
    RPM_PATTERN="${RPM_PATTERN}[.]rpm[\"]"
    RPMFILES=$(grep -Eo "${RPM_PATTERN}" "$TMPFILE" | cut -d\" -f2 | sort -u)

    for RPMFILE in ${RPMFILES}; do
        # Strip off .rpm
        TMPNAME=$(echo "$RPMFILE" | sed 's/[.]rpm$//')
        # If archstrip is true, strip off .arch
        [ "$ARCHSTRIP" = true ] && TMPNAME=$(echo "$TMPNAME" | sed "s/[.]${ARCH}$//")
        # Now grep for image_name-semver, then chop off the image_name- prefix
        SEMVER=$(echo "$TMPNAME" | grep -Eo "^${RPM_PREFIX_PATTERN}" | sed "s/^${IMAGE_NAME}-//")
        echo "${SEMVER} ${RPMFILE}"
    done > "$TMPFILE"

else

    # Even if it is set, we do not pass in the type argument if we are
    # using arti, because for arti the type is baked into the URL itself.
    # Same for RPMs
    [ -n "$TYPE" ] && [ "$SERVER" != "arti" ] && 
        OPTIONAL_ARGS="${OPTIONAL_ARGS} --type $TYPE"
fi

# Now call latest_version.py located in this directory
UEV=$("$MYDIR_PATH/latest_version.py" "--${DOCKER_HELM_RPM}" --file "$TMPFILE" --image "${IMAGE_NAME}" ${OPTIONAL_ARGS})
rc=$?
rm -f "$TMPFILE" >/dev/null 2>&1
[ $rc -ne 0 ] && exit 1

info "Found version ${UEV} of ${IMAGE_NAME}"
echo "$UEV" > $OUTFILE || err_exit "Error writing to $OUTFILE"
if [ "${DOCKER_HELM_RPM}" = rpm ]; then
    if [ -n "$NAMEFILE" ]; then
        RPMNAME=$(cat $NAMEFILE) || err_exit "Error reading from $NAMEFILE"
        info "RPM filename is $RPMNAME"
    elif [ -n "$URLFILE" ]; then
        RPMNAME=$(cat $URLFILE) || err_exit "Error reading from $URLFILE"
    fi

    if [ -n "$URLFILE" ]; then
        # Preprend our URL to it, and write it to URLFILE
        RPMURL="${URL}/${RPMNAME}"
        # Remove redundant // from RPMURL
        RPMURL=$(echo "$RPMURL" | sed 's#\([^:/]\)///*#\1/#g')
        info "RPM URL is $RPMURL"
        echo "${RPMURL}" > $URLFILE || err_exit "Error writing to $URLFILE"
    fi
fi
exit 0

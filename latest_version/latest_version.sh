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
USAGE="\
usage: latest_version.sh [--major x [--minor y]]
                         [--docker | --helm | --python] [--type <type>]
                         [[--server <server>] [--team <team>]  | [--url <url>]]
                         [--outfile <file> [--overwrite]]
                         [--artifactory-username-var <artifactory_username_var>]
                         [--artifactory-password-var <artifactory_password_var>]
                         image_name
       latest_version.sh {-h || --help}"

USAGE_EXTRA="\
server: algol60 or arti. Defaults to algol60 (unless url is specified, in which case it is not used)
team: Defaults to csm (unless url is specified, in which case it is not used)
type: Defaults to stable (unless url is specified, in which case it may still be specified but has no
default value if it is not specified)

For server arti:
docker: use https://arti.hpc.amslabs.hpecorp.net/artifactory/<team>-docker-<type>-local/repository.catalog
helm: use https://arti.hpc.amslabs.hpecorp.net/artifactory/<team>-helm-<type>-local/index.yaml
python: use https://arti.hpc.amslabs.hpecorp.net/artifactory/csm-python-modules-local/simple/<module_name>/

For server algol60:
docker: use https://artifactory.algol60.net/artifactory/<team>-docker/repository.catalog
helm: use https://artifactory.algol60.net/artifactory/<team>-helm-charts/index.yaml
python: use https://artifactory.algol60.net/artifactory/csm-python-modules/simple/<module_name>/

For url, the file at the specified URL will be used.
docker: Assumes file is in the same JSON format as the arti/algol60 repository.catalog files
helm: Assumes file is in the same YAML format as the arti/algol60 index.yaml files
python: Assumes directory index of .tar.gz files and -py3-none-any.whl files.

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
DOCK_HELM_PYTH=""
OUTFILE=""
OVERWRITE=N
SERVER=""
URL=""
ARTIFACTORY_USERNAME_VAR=""
ARTIFACTORY_PASSWORD_VAR=""

function parse_arguments
{
    while [ $# -gt 0 ]; do
        case "$1" in
            "--docker"|"--helm"|"--python")
                [ -n "$DOCK_HELM_PYTH" ] && usage "--docker, --helm, and --python must be specified no more than once total"
                DOCK_HELM_PYTH=$(echo "$1" | sed 's/^[-][-]//')
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
            "--artifactory-username-var")
                [ -z "$2" ] && usage "Variable name for Artifactory username may not be blank"
                ARTIFACTORY_USERNAME_VAR="$2"
                shift 2
                ;;
            "--artifactory-password-var")
                [ -z "$2" ] && usage "Variable name for Artifactory password may not be blank"
                ARTIFACTORY_PASSWORD_VAR="$2"
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
    [ -z "$DOCK_HELM_PYTH" ] && DOCK_HELM_PYTH="docker"
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
    # For arti, use HPE_ARTIFACTORY_USR/PSW vars provided by DST pipeline.
    [ -z "$ARTIFACTORY_USERNAME_VAR" ] && ARTIFACTORY_USERNAME_VAR=$([ "$SERVER" == "arti" ] && echo HPE_ARTIFACTORY_USR || echo ARTIFACTORY_USERNAME)
    [ -z "$ARTIFACTORY_PASSWORD_VAR" ] && ARTIFACTORY_PASSWORD_VAR=$([ "$SERVER" == "arti" ] && echo HPE_ARTIFACTORY_PSW || echo ARTIFACTORY_PASSWORD)
    [ -z "${!ARTIFACTORY_USERNAME_VAR}" ] && usage "Artifactory username must be specified via ${ARTIFACTORY_USERNAME_VAR} environment variable. Variable name may be adjusted via --artifactory-username-var parameter."
    [ -z "${!ARTIFACTORY_PASSWORD_VAR}" ] && usage "Artifactory password must be specified via ${ARTIFACTORY_PASSWORD_VAR} environment variable. Variable name may be adjusted via --artifactory-password-var parameter."
}

parse_arguments "$@"
if [ -z "$URL" ]; then
    if [ "$SERVER" = "arti" ]; then
        case "${DOCK_HELM_PYTH}" in
            "docker") URL="https://arti.hpc.amslabs.hpecorp.net/artifactory/api/docker/${TEAM}-docker-${TYPE}-local/v2/${IMAGE_NAME}/tags/list" ;;
            "helm")   URL="https://arti.hpc.amslabs.hpecorp.net/artifactory/${TEAM}-helm-${TYPE}-local/index.yaml" ;;
            "python") URL="https://arti.hpc.amslabs.hpecorp.net/artifactory/csm-python-modules-local/simple/${IMAGE_NAME}/" ;;
        esac
    else
        # algol60
        case "${DOCK_HELM_PYTH}" in
            "docker") URL="https://artifactory.algol60.net/artifactory/api/docker/${TEAM}-docker/v2/${TYPE}/${IMAGE_NAME}/tags/list" ;;
            "helm")   URL="https://artifactory.algol60.net/artifactory/${TEAM}-helm-charts/index.yaml" ;;
            "python") URL="https://artifactory.algol60.net/artifactory/csm-python-modules/simple/${IMAGE_NAME}/" ;;
        esac
    fi
fi

case "${DOCK_HELM_PYTH}" in
    "docker")   TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.repository.catalog.json" ;;
    "helm")     # Test to see if yaml module is available
                . "${CMS_META_TOOLS_PATH}/utils/pyyaml.sh"
                TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.index.yaml" ;;
    "python")   TMPFILE="/tmp/.latest_version.sh.$$.$RANDOM.html" ;;
esac

trap "rm -f $TMPFILE" EXIT
echo "latest_version.sh: url=$URL" 1>&2

if ! curl -sSf -u "${!ARTIFACTORY_USERNAME_VAR}:${!ARTIFACTORY_PASSWORD_VAR}" -o "$TMPFILE" "$URL" 1>&2 ; then
    err_exit "Command failed: curl -sSf -o $TMPFILE $URL"
fi

if [ "${DOCK_HELM_PYTH}" == python ]; then
    # Extract just the version strings from the index, sort them by version, take the first one
    # Some of the Python package files used underscores instead of dashes, so we will search for either.
    image_regex=${IMAGE_NAME//[-_]/[-_]}
    version_regex="^"
    if [[ -n ${MAJOR} ]]; then
        version_regex+="${MAJOR}[.]"
        [[ -n ${MINOR} ]] && version_regex+="${MINOR}[.]"
    fi
    UEV=$(grep -Eo "\"${image_regex}-([0-9]+[.]){2}[0-9]+(-py3-none-any[.]whl|[.]tar[.]gz)\"" "${TMPFILE}" |
            sed -e "s/^\"${image_regex}-//" -e "s/-py3-none-any[.]whl\"$//" -e "s/[.]tar[.]gz\"$//" |
            grep -E "${version_regex}" | sort -uVr | head -1)
    [[ ! $UEV =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] && err_exit "Unable to determine latest available version of ${IMAGE_NAME} Python module"
else
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
    UEV=$("$MYDIR_PATH/latest_version.py" "--${DOCK_HELM_PYTH}" --file "$TMPFILE" --image "${IMAGE_NAME}" ${OPTIONAL_ARGS}) || exit 1
fi

info "Found version ${UEV} of ${IMAGE_NAME}"
echo "$UEV" > $OUTFILE && exit 0
err_exit "Error writing to $OUTFILE"

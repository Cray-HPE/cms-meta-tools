#!/usr/bin/env sh

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

# Since this repo uses dynamic versioning, it can be more complicated going
# from a version number back to the source code from which it arose. This
# tool is run at build time to collect information on what is being built.
# It stores its output in gitInfo.txt, and this file is included in Docker
# images and RPMs created by the build. It also appends some annotation
# metadata to the k8s chart being built.

GITINFO_CONFIG=git_info.conf
GITINFO_OUTFILE=gitInfo.txt
MYNAME=$(basename $0)

function myecho
{
    echo "${MYNAME} $*"
}

function error_exit
{
    myecho "ERROR: $*" 1>&2
    exit 1
}

function run_cmd
{
    local rc
    "$@"
    rc=$?
    if [ $rc -ne 0 ]; then
        error_exit "Command failed with return code $rc: $*" 1>&2
    fi
    return 0
}

if [ ! -e "${GITINFO_CONFIG}" ]; then
    myecho "No ${GITINFO_CONFIG} found -- nothing to do"
    exit 0
elif [ ! -f "${GITINFO_CONFIG}" ]; then
    ls -al "${GITINFO_CONFIG}" 1>&2
    error_exit "${GITINFO_CONFIG} exists but is not a file"
fi

GIT_BRANCH=$(run_cmd git rev-parse --abbrev-ref HEAD)
TMPFILE=.git_info.tmp.$$.$RANDOM.$RANDOM
while [ -e "$TMPFILE" ]; do
    TMPFILE=.git_info.tmp.$$.$RANDOM.$RANDOM
done
run_cmd git log -n 1 --pretty=tformat:"%H %cI %cd" --date=format:"%a %b %d %Y" > "$TMPFILE"
read -r GIT_COMMIT_ID GIT_COMMIT_DATE GIT_COMMIT_CHANGELOG_DATE <<< $(head -1 "$TMPFILE")
rm -f "$TMPFILE"
echo "git branch: ${GIT_BRANCH}" > "${GITINFO_OUTFILE}" ||
    error_exit "Unable to write to ${GITINFO_OUTFILE}"
run_cmd git log --decorate=full --source -n 1 >> "${GITINFO_OUTFILE}"
myecho "Created ${GITINFO_OUTFILE}:"
run_cmd cat "${GITINFO_OUTFILE}"

CHART_ANNOTATIONS="\
annotations:
  git/branch: \"${GIT_BRANCH}\"
  git/commit-date: \"${GIT_COMMIT_DATE}\"
  git/commit-id: \"${GIT_COMMIT_ID}\"\
"

CHANGELOG=.git_info.specfile_changelog.tmp.$$.$RANDOM.$RANDOM
while [ -e "$CHANGELOG" ]; do
    CHANGELOG=.git_info.specfile_changelog.tmp.$$.$RANDOM.$RANDOM
done

run_cmd cat > "$CHANGELOG" << EOF
* ${GIT_COMMIT_CHANGELOG_DATE} Cray HPE - %{version}
- build git metadata
- branch: ${GIT_BRANCH}
- commit-date: ${GIT_COMMIT_DATE}
- commit-id: ${GIT_COMMIT_ID}
EOF

DOCKERCOPY=.git_info.specfile_changelog.tmp.$$.$RANDOM.$RANDOM
while [ -e "$DOCKERCOPY" ]; do
    DOCKERCOPY=.git_info.specfile_changelog.tmp.$$.$RANDOM.$RANDOM
done

echo "COPY ${GITINFO_OUTFILE} ${GITINFO_OUTFILE}" > "$DOCKERCOPY" ||
    error_exit "Unable to write to $DOCKERCOPY"

myecho "Processing ${GITINFO_CONFIG}..."
while read vars; do
    type=""
    target=""
    clist=""
    if [[ "$vars" =~ ^dockerfile: ]]; then
        read -r type target clist
    else
        read -r type target
    fi <<< $(echo $vars | sed 's/:/ /')
    if [ -z "$target" ]; then
        error_exit "No target file specified for $type"
    elif [ ! -e "${target}" ]; then
        error_exit "${type} ${target} does not exist"
    elif [ ! -f "${target}" ]; then
        ls -al "${target}" 1>&2
        error_exit "${type} ${target} exists but is not a regular file"
    fi
    if [ "$type" = chart ]; then
        # Make copy of original file, for comparison
        run_cmd cp "$target" "$TMPFILE"
        myecho "Appending git metadata to ${target}"
        echo "${CHART_ANNOTATIONS}" >> "${target}" || 
            error_exit "Error appending to ${target}"
        diff "$target" "$TMPFILE" && 
            error_exit "Append seemed to work but $target is unchanged"
        rm -f "$TMPFILE"
    elif [ "$type" = dockerfile ]; then
        [ -n "$clist" ] || 
            error_exit "No container names specified for dockerfile $target"
        for cname in $clist ; do
            grep -Eq "^FROM .* as $cname[[:space:]]*$" "$target" ||
                error_exit "No FROM line for $cname found in $target"
            myecho "Adding line to copy git metadata into $cname in $target"
            run_cmd sed "/^FROM .* as $cname[[:space:]]*$/r ${DOCKERCOPY}" "$target" > "$TMPFILE" || 
                error_exit "Error writing to $TMPFILE"
            diff "$target" "$TMPFILE" && 
                error_exit "Append seemed to work but no changes were made"
            run_cmd cp "$TMPFILE" "$target"
            rm -f "$TMPFILE"
        done
    elif [ "$type" = specfile ]; then
        grep -Eq "^%changelog[[:space:]]*$" "$target" || 
            error_exit "No %changelog line found in $target"
        myecho "Inserting git metadata into ${specfile} changelog"
        run_cmd sed "/^%changelog[[:space:]]*$/r ${CHANGELOG}" "$target" > "$TMPFILE" || 
            error_exit "Error writing to $TMPFILE"
        diff "$target" "$TMPFILE" && 
            error_exit "Append seemed to work but no changes were made"
        run_cmd cp "$TMPFILE" "$target"
        rm -f "$TMPFILE"
    else
        # Should never see this, based on the grep command we run on the config file
        error_exit "PROGRAMMING LOGIC ERROR: Unexpected value of vars = $vars"
    fi
done <<-EOF
$(grep -E '^(chart|dockerfile|specfile):' "${GITINFO_CONFIG}")
EOF

[ -f "$TMPFILE" ] && rm -f "$TMPFILE"
[ -f "$CHANGELOG" ] && rm -f "$CHANGELOG"
[ -f "$DOCKERCOPY" ] && rm -f "$DOCKERCOPY"

myecho "SUCCESS"
exit 0

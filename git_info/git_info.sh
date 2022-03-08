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
# Since this repo uses dynamic versioning, it can be more complicated going
# from a version number back to the source code from which it arose. This
# tool is run at build time to collect information on what is being built.
# It stores its output in gitInfo.txt, and this file is included in Docker
# images and RPMs created by the build. It also appends some annotation
# metadata to the k8s chart being built.

GITINFO_CONFIG=git_info.conf
GITINFO_OUTFILE=gitInfo.txt
MYNAME="git_info"

function info
{
    echo "$MYNAME: $*"
}

function err_exit
{
    info "ERROR: $*" 1>&2
    exit 1
}

function run_cmd
{
    local rc
    "$@"
    rc=$?
    if [ $rc -ne 0 ]; then
        err_exit "Command failed with return code $rc: $*" 1>&2
    fi
    return 0
}

function sed_diff_replace
{
    # usage: <target file> <tmp file> <sed command argument>
    local target tmpfile sedarg
    [ $# -ne 3 ] && err_exit "Programming error: sed_diff_replace expects 3 but received $# argument(s): $*"
    target="$1"
    tmpfile="$2"
    sedarg="$3"
    run_cmd sed "$sedarg" "$target" > "$tmpfile" || 
        err_exit "sed command failed or error writing to $tmpfile"
    diff "$target" "$tmpfile" && 
        err_exit "sed command ran but no changes were made"
    run_cmd cp -v "$tmpfile" "$target"
    rm -fv "$tmpfile"
    return 0
}

if [ ! -e "${GITINFO_CONFIG}" ]; then
    info "No ${GITINFO_CONFIG} found -- nothing to do"
    exit 0
elif [ ! -f "${GITINFO_CONFIG}" ]; then
    ls -al "${GITINFO_CONFIG}" 1>&2
    err_exit "${GITINFO_CONFIG} exists but is not a file"
fi

GIT_BRANCH=$(run_cmd git rev-parse --abbrev-ref HEAD)
TMPFILE=.git_info.tmp.$$.$RANDOM.$RANDOM
while [ -e "$TMPFILE" ]; do
    TMPFILE=.git_info.tmp.$$.$RANDOM.$RANDOM
done
run_cmd git log -n 1 --pretty=tformat:"%H %cI %cd" --date=format:"%a %b %d %Y" > "$TMPFILE"
read -r GIT_COMMIT_ID GIT_COMMIT_DATE GIT_COMMIT_CHANGELOG_DATE <<< $(head -1 "$TMPFILE")
rm -fv "$TMPFILE"
echo "git branch: ${GIT_BRANCH}" > "${GITINFO_OUTFILE}" ||
    err_exit "Unable to write to ${GITINFO_OUTFILE}"
run_cmd git log --decorate=full --source -n 1 >> "${GITINFO_OUTFILE}"
info "Created ${GITINFO_OUTFILE}:"
run_cmd cat "${GITINFO_OUTFILE}"

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
    err_exit "Unable to write to $DOCKERCOPY"

info "Processing ${GITINFO_CONFIG}..."
while read vars; do
    type=""
    target=""
    clist=""
    if [[ "$vars" =~ ^dockerfile: ]]; then
        read -r type target clist
    else
        read -r type target
    fi <<< $(echo $vars | sed 's/:/ /')
    if [ -z "$type" ]; then
        # This should only be the case when our config file has no stanzas for us to process
        # That is not necessarily a mistake -- it can be used if one only wants gitInfo.txt
        # generated, but nothing else
        info "WARNING: It appears there are no stanzas in git_info.conf. If this is intentional, all is well." 1>&2
        continue
    elif [ -z "$target" ]; then
        err_exit "No target file specified for $type"
    elif [ ! -e "${target}" ]; then
        err_exit "${type} ${target} does not exist"
    elif [ ! -f "${target}" ]; then
        ls -al "${target}" 1>&2
        err_exit "${type} ${target} exists but is not a regular file"
    fi
    if [ "$type" = chart ]; then
        # Make copy of original file, for comparison
        run_cmd cp -v "$target" "$TMPFILE"
        info "Appending git metadata to ${target}"
        if ! grep -Eq '^annotations:[[:space:]]*$' "${target}"; then
            echo "annotations:" >> "${target}" ||
                err_exit "Error appending to ${target}"
        fi
        sed -e "s,^annotations:\s*$,annotations:\n  git/branch: \"${GIT_BRANCH}\"\n  git/commit-date: \"${GIT_COMMIT_DATE}\"\n  git/commit-id: \"${GIT_COMMIT_ID}\"," "${target}" > "${target}.tmp" ||
            err_exit "Error appending to ${target}"
        run_cmd mv "${target}.tmp" "${target}"
        diff "$target" "$TMPFILE" && 
            err_exit "Append seemed to work but $target is unchanged"
        rm -fv "$TMPFILE"
    elif [ "$type" = dockerfile ]; then
        [ -n "$clist" ] || 
            err_exit "No container names specified for dockerfile $target"
        for cname in $clist ; do
            grep -Eq "^FROM .* as $cname[[:space:]]*$" "$target" ||
                err_exit "No FROM line for $cname found in $target"
            info "Adding line to copy git metadata into $cname in $target"
            sed_diff_replace "$target" "$TMPFILE" "/^FROM .* as $cname[[:space:]]*$/r ${DOCKERCOPY}"
        done
    elif [ "$type" = specfile ]; then
        if ! grep -Eq "^%changelog[[:space:]]*$" "$target" ; then
            info "No %changelog line found in $target -- appending one"
            echo -e "\n\n%changelog" >> "$target" ||
                err_exit "Error writing to $target"
        fi
        info "Inserting git metadata into ${specfile} changelog"
        sed_diff_replace "$target" "$TMPFILE" "/^%changelog[[:space:]]*$/r ${CHANGELOG}"
    else
        # Should never see this, based on the grep command we run on the config file
        err_exit "PROGRAMMING LOGIC ERROR: Unexpected value of vars = $vars"
    fi
done <<-EOF
$(grep -E '^(chart|dockerfile|specfile):' "${GITINFO_CONFIG}")
EOF

[ -f "$TMPFILE" ] && rm -fv "$TMPFILE"
[ -f "$CHANGELOG" ] && rm -fv "$CHANGELOG"
[ -f "$DOCKERCOPY" ] && rm -fv "$DOCKERCOPY"

info "SUCCESS"
exit 0

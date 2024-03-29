#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2020-2022 Hewlett Packard Enterprise Development LP
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
# This file is based on the file of the same name in the sample_scripts 
# directory in the cms-meta-tools repo. If you have problems with it, 
# there may be a newer version of the file in that repo which corrects
# the problem.

# The following two variables determine which versions of the cms-meta-tools RPM will be considered
REL_MAJOR=3
REL_MINOR=0
CMT_RPMS_URL=https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp2/cms-meta-tools/noarch/
RETRY_MINUTES=10

# Find latest cms-meta-tools RPM in our chosen release
function cmt-rpm-url
{
    local tmpfile
    local stop
    
    tmpfile=/tmp/.cmt-rpm-url.$$.$RANDOM.$RANDOM.$RANDOM.tmp
    let stop=SECONDS+60*RETRY_MINUTES

    while [ true ]; do
        if ! curl -is $CMT_RPMS_URL > $tmpfile ; then
            echo "ERROR: curl command failed or error writing to $tmpfile" 1>&2
            return 1
        elif head -1 $tmpfile | grep -wq "5[0-9][0-9]" ; then
            if [ $SECONDS -lt $stop ]; then
                echo "WARNING: Temporary server error returned by $CMT_RPMS_URL. Will retry query in 30 seconds" 1>&2
            else
                echo "ERROR: Still receiving server errors after retrying for over $RETRY_MINUTES minutes" 1>&2
                return 1
            fi
            sleep 30
            continue
        fi
        break
    done

    if ! grep -Eqo "cms-meta-tools-[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*-[0-9][0-9]*[.]noarch[.]rpm" $tmpfile ; then
        echo "ERROR: No cms-meta-tools RPMs found in $CMT_RPMS_URL" 1>&2
        cat $tmpfile 1>&2
        return 1
    elif ! grep -Eqo "cms-meta-tools-${REL_MAJOR}[.]${REL_MINOR}[.][0-9][0-9]*-[0-9][0-9]*[.]noarch[.]rpm" $tmpfile ; then
        echo "ERROR: No cms-meta-tools RPMs with version ${REL_MAJOR}.${REL_MINOR} found in $CMT_RPMS_URL" 1>&2
        cat $tmpfile 1>&2
        return 1
    fi
    cat $tmpfile | 
        # Filter out everything except the RPM names
        grep -Eo "cms-meta-tools-${REL_MAJOR}[.]${REL_MINOR}[.][0-9][0-9]*-[0-9][0-9]*[.]noarch[.]rpm" | 
        # Extract the version and print those numbers followed by the full URL to the RPM
        sed "s#^cms-meta-tools-[0-9][0-9]*[.][0-9][0-9]*[.]\([0-9][0-9]*\)-\([0-9][0-9]*\)[.].*\$#\1 \2 $CMT_RPMS_URL\0#" |
        # Sort numerically by those fields, higher numbers first 
        sort -u -n -r -t" " -k1 -k2 | 
        # Take the first one and print only the RPM URL
        head -1 | awk -F" " '{ print $NF }'
    return 0
}

if ! RPM_URL=$(cmt-rpm-url) || [ -z "${RPM_URL}" ]; then
    echo "ERROR: Unable to find latest cms-metal-tools RPM" 1>&2
    exit 1
fi
echo "cms-meta-tools RPM: $RPM_URL"

TRGDIR=$(pwd)/cms_meta_tools
mkdir -pv "$TRGDIR" || exit 1

# Install the rpm into this directory, do not check/update the rpm db, and (because of that) do not check dependencies
rpm -Uvh --relocate /opt/cray/cms-meta-tools="$TRGDIR" --nodeps --dbpath "$TRGDIR" $RPM_URL || exit 1
exit 0

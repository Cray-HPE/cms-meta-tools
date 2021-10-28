#!/bin/sh
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

# This script is intended to be copied into a Docker image and run,
# in order to apply necessary patches (typically security patches).
# Ideally it should come after all other zypper commands and RPM
# installs (to avoid the case where you zypper install something later
# and fail to apply security patches for it or its dependencies that
# get pulled in).

# Run with set -x to help with debugging
set -x

# Apply necessary patches in a while loop. This is done because
# the zypper patch command returns 103 when it has successfully applied
# a patch to itself, but it needs to be re-run in order to apply the remaining
# patches. 

# I do not know if this is guaranteed to only happen a single time per execution,
# so in the case of 103 return codes, we will retry up to 10 times before
# failing.

count=0
while [ $count -lt 10 ]; do
    zypper --non-interactive patch
    rc=$?

    # If rc = 0, break out of the while loop
    [ $rc -eq 0 ] && break

    # If rc != 103, then this is a true failure
    [ $rc -ne 103 ] && exit $rc

    # If rc = 103, increment count and retry
    let count+=1
done

# If count = 10, that means the zypper command never gave return code 0
[ $count -eq 10 ] && exit 103

# Finally, clean up package caches and metadata
zypper clean -a
exit $?

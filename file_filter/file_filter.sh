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

MYDIR=$(dirname ${BASH_SOURCE[0]})

# Now call file_filter located in this directory, with same arguments this script was passed
$MYDIR/file_filter.py "$@"
exit $?

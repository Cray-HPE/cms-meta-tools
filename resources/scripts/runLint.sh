#!/usr/bin/env sh

# Copyright 2020-2021 Hewlett Packard Enterprise Development LP
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

# Find my directory, so I know where to find my friends
MYDIR=$(dirname ${BASH_SOURCE[0]})
CMTROOT=$MYDIR/..

# These do not take long to run, and do not depend on each other, so we let
# them run even if one fails, so the build can report all problems found.
RC=0

# No config file is needed for this tool. The defaults are fine in many cases,
# but it should run in every repo.
$CMTROOT/copyright_license_check/copyright_license_check.sh || RC=1

# If there is no go code in the repo, this tool will do nothing and have
# exit code 0
$CMTROOT/go_lint/go_lint.sh || RC=1

exit $RC

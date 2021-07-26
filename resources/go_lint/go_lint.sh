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

# Very simple scanner for Go files which runs the gofmt linter on them
# 
# It should be called from the root of the target repo
# Usage: go_lint.sh

TMPFILE1=/tmp/.go_lint.$$.$RANDOM.tmp.1
TMPFILE2=/tmp/.go_lint.$$.$RANDOM.tmp.2

function scan_file {
    local out
    local rc
    echo -n "Scanning $1 with gofmt... "
    # skip empty files
    if [ -s "$1" ]; then
        out=$(gofmt -s -l "$1")
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "UNEXPECTED ERROR: gofmt exited with return code $rc"
            return 1
        # gofmt return code is 0 regardless of whether or not it finds problems.
        # It outputs nothing if the file is okay, otherwise it outputs the
        # filename. So we check to see if we got any output or not.
        elif [ -n "$out" ]; then
            echo "ERROR"
            return 1
        fi
    fi
    echo "OK"
    return 0
}

GL_CONF="go_lint.yaml"

# Default config file should be located in the same directory as this script
GL_DIR=$(dirname ${BASH_SOURCE[0]})
echo "gl should be located in directory $GL_DIR"
DEFAULT_GL_CONF="$GL_DIR/$GL_CONF"
if [ -s "$DEFAULT_GL_CONF" ]; then
    echo "Located default gl config file: $DEFAULT_GL_CONF"
else
    if [ -f "$DEFAULT_GL_CONF" ]; then
        echo "File is zero size: $DEFAULT_GL_CONF"
    elif [ -e "$DEFAULT_GL_CONF" ]; then
        echo "Exists but is not a file: $DEFAULT_GL_CONF"
    elif [ -d "$GL_DIR" ]; then
        echo "$GL_DIR directory exists but does not contain $GL_CONF"
    elif [ -e "$GL_DIR" ]; then
        echo "$GL_DIR exists but is not a directory"
    else
        echo "Does not exist: $GL_DIR"
    fi
    echo "BASH_SOURCE = ${BASH_SOURCE[*]}"
    echo "ERROR: Unable to locate gl directory and/or config file $GL_CONF" 1>&2
    exit 1
fi

REPO_GL_CONF=./$GL_CONF
if [ -f "$REPO_GL_CONF" ]; then
    echo "Found repo gl config file: $REPO_GL_CONF"
else
    echo "No repo-specific gl config file. Default only will be used."
    REPO_GL_CONF=""
fi

FF_SH="file_filter.sh"
# file_filter script should be in a sibling directory to this one
FF_DIR="$GL_DIR/../file_filter"
FF_TARGETS="$FF_DIR/$FF_SH"
if [ -x "$FF_TARGETS" ] && [ -s "$FF_TARGETS" ]; then
    echo "Located $FF_SH in $FF_DIR"
else
    if [ -x "$FF_TARGETS" ]; then
        echo "File is zero size: $FF_TARGETS"
    elif [ -s "$FF_TARGETS" ]; then
        echo "File is not executable: $FF_TARGETS"
    elif [ -f "$FF_TARGETS" ]; then
        echo "File is zero size and not executable: $FF_TARGETS"
    elif [ -e "$FF_TARGETS" ]; then
        echo "Exists but is not a file: $FF_TARGETS"
    elif [ -d "$FF_DIR" ]; then
        echo "Does not exist: $FF_TARGETS"
    elif [ -e "$FF_DIR" ]; then
        echo "Exists but is not a directory: $FF_DIR"
    else
        echo "Does not exist: $FF_DIR"
    fi
    echo "BASH_SOURCE = ${BASH_SOURCE[*]}"
    echo "ERROR: Problem with $FF_SH in $FF_DIR directory." 1>&2
    exit 1
fi

if ! git ls-files --empty-directory > $TMPFILE1 ; then
    echo "ERROR: Command failed:  git ls-files --empty-directory" 1>&2
    rm -f $TMPFILE1 >/dev/null 2>&1
    exit 1
fi

# $REPO_GL_CONF not in quotes because we know it has no whitespace and because if it is
# blank (meaning there is no repo gl config file), we do not want it passed as an empty
# string argument
if ! cat $TMPFILE1 | "$FF_TARGETS" "$DEFAULT_GL_CONF" $REPO_GL_CONF > $TMPFILE2 ; then
    echo "ERROR: $FF_TARGETS failed" 1>&2
    rm -f $TMPFILE1 $TMPFILE2 >/dev/null 2>&1
    exit 1
elif [ ! -s "$TMPFILE2" ]; then
    echo "No go code found to scan that met the filtering criteria"
    exit 0
fi

FAIL=0

while read FILE ; do
    scan_file "$FILE" || FAIL=1
done << EOF
$(cat $TMPFILE2)
EOF

rm -f $TMPFILE1 $TMPFILE2 >/dev/null 2>&1

if [ $FAIL -eq 0 ]; then
    echo "All scanned code passed"
else
    echo "Some code failed gofmt check, see list above" 1>&2
    echo "To fix detected errors in a file, run: gofmt -s -l -w <filename>" 1>&2
fi

exit $FAIL
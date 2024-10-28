#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
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

# Usage: get_python_bin.sh <python_major>.<python_minor>

# Outputs the full path to the associated system Python binary, if it is present

myname=$(basename "$0")

function check_py_binary
{
    local path
    path="/usr/bin/python$1"
    [[ -f ${path} && -x ${path} ]] && echo "${path}" && exit 0
}

function print_err
{
    echo "${myname}: ERROR: $*" >&2
}

function err_exit
{
    print_err "$*"
    exit 1
}

function usage_err_exit
{
    print_err "$*"
    exit 2
}

py_dotted_version_pattern='^[1-9][0-9]*[.][0-9]+$'

if [[ $# -ne 1 ]]; then
    usage_err_exit "This script requires exactly 1 argument but received $#: $*"
elif [[ -z $1 ]]; then
    usage_err_exit "Argument to this script may not be blank"
elif [[ ! $1 =~ ${py_dotted_version_pattern} ]]; then
    usage_err_exit "Argument to this script must be <python major version>.<python minor version>. Invalid argument: $1"
fi

PY_VERSION="$1"
check_py_binary "${PY_VERSION}"
check_py_binary "${PY_VERSION//.}"
err_exit "Cannot find binary for python version ${PY_VERSION}"

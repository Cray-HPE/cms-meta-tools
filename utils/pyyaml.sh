#
# MIT License
#
# (C) Copyright 2021-2022, 2024 Hewlett Packard Enterprise Development LP
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
function pyyaml_info
{
    # If our parent script has $MYNAME set, include it:
    if [ -n "$MYNAME" ]; then
        echo "$MYNAME: pyyaml.sh: $*" 1>&2
    else
        echo "pyyaml.sh: $*" 1>&2
    fi
}

function pyyaml_err
{
    pyyaml_info "ERROR: $*"
}

function pyyaml_err_exit
{
    # If our parent has err_exit defined, we'll use it
    if declare -F | grep -wq err_exit; then
        err_exit "pyyaml.sh: $*"
        # We should not reach this line, but just in case the
        # err_exit function does not do what we expect, we will
        # continue this function to try a backup plan
    fi
    pyyaml_err "$*"
    exit 1
}

function pyyaml_validate_dir
{
    [ $# -ne 1 ] && pyyaml_err_exit "Programming error: pyyaml_validate_dir expects exactly 1 but received $# arguments: $*"
    if [ ! -e "$1" ]; then
        pyyaml_err "Path does not exist: '$1'"
        return 1
    elif [ ! -d "$1" ]; then
        ls -al "$1"
        pyyaml_err "Path exists but is not a directory: '$1'"
        return 1
    fi
    return 0
}

function pyyaml_pip3_install
{
    # Usage: pyyaml_pip3_install <module> [<module>] ...
    # Assumes PYMODDIR has been set
    #--trusted-host arti.hpc.amslabs.hpecorp.net \
    #--index-url https://arti.hpc.amslabs.hpecorp.net:443/artifactory/api/pypi/pypi-remote/simple \
    pip3 install "$@" \
        --no-cache-dir \
        --ignore-installed \
        --target="$PYMODDIR" \
        --upgrade 1>&2
}

GET_PIP_DONE=0

function pyyaml_get_pip
{
    # Only do this once
    # Assumes PYMODDIR has been set
    [[ $GET_PIP_DONE -eq 0 ]] || return
    
    # In case this is an alpine container
    apk add --no-cache python3 > /dev/null 2>&1
    apk add --no-cache py3-pip > /dev/null 2>&1
    python3 -m ensurepip 1>&2

    # Get the latest pip, setuptools, and wheel
    pyyaml_pip3_install pip setuptools wheel

    # Remember that we have already done this
    GET_PIP_DONE=1
}

function pyyaml_collect_debug_info
{
    # Collect some debug information
    # Assumes PYMODDIR has been set
    ls "$PYMODDIR" 1>&2
    python3 --version 1>&2
    pip3 --version 1>&2
    uname -a 1>&2
    cat /etc/*release* 1>&2
    pip3 list 1>&2
}

function pyyaml_install_if_needed
{
    # Usage: pyyaml_install_if_needed <module_name_import> [<module_name_pip>]
    # Assumes PYMODDIR has been set
    local IMPORT_MOD PIP_MOD
    IMPORT_MOD="$1"
    if [ $# -eq 1 ]; then
        # Assume both names are the same
        PIP_MOD="$1"
    else
        PIP_MOD="$2"
    fi

    # Test to see if we can import the module
    pyyaml_info "Checking if Python3 ${PIP_MOD} module is available" 1>&2

    if ! python3 -c "import ${IMPORT_MOD}" >/dev/null 1>&2 ; then
        pyyaml_info "Installing ${PIP_MOD} into $PYMODDIR" 1>&2

        pyyaml_get_pip

        pyyaml_pip3_install "${PIP_MOD}"

        if ! python3 -c "import ${IMPORT_MOD}" 1>&2 ; then
            pyyaml_collect_debug_info
        
            pyyaml_info "ERROR: Unable to install Python3 ${PIP_MOD} module" 1>&2
            exit 1
        fi
    fi

    pyyaml_info "Python3 ${PIP_MOD} module is available"
}

# This file assumes that any script sourcing it will have set the variable
# CMS_META_TOOLS_PATH
if [ -z "${CMS_META_TOOLS_PATH}" ]; then
    pyyaml_err_exit "CMS_META_TOOLS_PATH variable not set"
elif ! pyyaml_validate_dir "${CMS_META_TOOLS_PATH}" ; then
    pyyaml_err_exit "CMS_META_TOOLS_PATH variable set to invalid path"
elif ! pyyaml_validate_dir "${CMS_META_TOOLS_PATH}/utils" ; then
    pyyaml_err_exit "utils directory should be in the directory set by CMS_META_TOOLS_PATH"
fi

# Create our local python modules directory, if needed
PYMODDIR="${CMS_META_TOOLS_PATH}/pymods"

# Add it to our PYTHONPATH variable
export PYTHONPATH="${PYTHONPATH}:${PYMODDIR}"

pyyaml_install_if_needed yaml PyYAML
pyyaml_install_if_needed ruamel.yaml

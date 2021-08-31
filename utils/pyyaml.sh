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

CMT_UTILS_DIR=$(dirname ${BASH_SOURCE[0]})

# Test to see if yaml module is available
echo "Checking if yaml Python module is available" 1>&2
PYMODDIR="${CMT_UTILS_DIR}/pymods"
export PYTHONPATH="${PYTHONPATH}:${PYMODDIR}"
if ! python3 -c "import yaml" >/dev/null 1>&2 ; then
    echo "Installing yaml into $PYMODDIR" 1>&2

    # In case this is an alpine container
    apk add --no-cache python3 > /dev/null 2>&1
    apk add --no-cache py3-pip > /dev/null 2>&1
    
    python3 -m ensurepip 1>&2
    pip3 install PyYAML \
        --no-cache-dir \
        --trusted-host arti.dev.cray.com \
        --index-url https://arti.dev.cray.com:443/artifactory/api/pypi/pypi-remote/simple \
        --ignore-installed \
        --target="$PYMODDIR" \
        --upgrade 1>&2

    if ! python3 -c "import yaml" 1>&2 ; then
        # Collect some debug information
        ls "$PYMODDIR" 1>&2
        python3 --version 1>&2
        pip3 --version 1>&2
        uname -a 1>&2
        cat /etc/*release* 1>&2
        pip3 list 1>&2

        echo "ERROR: Unable to install Python yaml module" 1>&2
        exit 1
    fi
fi

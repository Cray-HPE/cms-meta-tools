#!/bin/bash

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

set -ex

CHART_PATH="$1"
APP_VERSION="$2"

if [ -d "${CHART_PATH}" ]; then
    dir="${CHART_PATH}"
    echo "image tag: ${APP_VERSION}"
    if [ -f "$dir/Chart.yaml" ]; then
        chart_name="${dir##*/}"
        echo "Updating appVersion for Helm chart at $dir"
    fi
    if [[ -f "$dir/Chart.yaml" ]] && [[ -f "$dir/values.yaml" ]] && [[ -n "${APP_VERSION}" ]]; then
        # update/append appVersion in values.yaml
        if grep "^\s*global:" "$dir/values.yaml"; then
            if grep "appVersion:" "$dir/values.yaml"; then
                sed -e "s/^\(\sappVersion:\).*/\1 ${APP_VERSION}/" "$dir/values.yaml" > "$dir/values.yaml.tmp"
            else
                sed -e "s/^global\s*$/global:\n  appVersion: ${APP_VERSION}/" "$dir/values.yaml" > "$dir/values.yaml.tmp"
            fi
            mv "$dir/values.yaml.tmp" "$dir/values.yaml"
        else
            echo -e "\nglobal:\n  appVersion: ${APP_VERSION}" >> "$dir/values.yaml"
        fi
        cat "$dir/values.yaml"

        # update/append appVersion in Chart.yaml
        if grep "appVersion:" "$dir/Chart.yaml"; then
            sed -e "s/appVersion:.*/appVersion: ${APP_VERSION}/" "$dir/Chart.yaml" > "$dir/Chart.yaml.tmp"
            mv "$dir/Chart.yaml.tmp" "$dir/Chart.yaml"
        else
            echo "appVersion: ${APP_VERSION}" >> "$dir/Chart.yaml"
        fi
        cat "$dir/Chart.yaml"
    else
        echo "WARN: Unable to set global.appVersion in $dir/Chart.yaml - the resulting Chart may not reference a specific image as a result"
    fi
fi

#!/bin/bash

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
        if grep "global:" "$dir/values.yaml"; then
            if grep "appVersion:" "$dir/values.yaml"; then
                sed -i "$dir/values.yaml" -e "s/appVersion:.*/appVersion: ${APP_VERSION}/"
            else
                sed -i "$dir/values.yaml" -e "s/^global\s*$/global:\n  appVersion: ${APP_VERSION}/"
            fi
        else
            echo -e "\nglobal:\n  appVersion: ${APP_VERSION}" >> "$dir/values.yaml"
        fi
        cat "$dir/values.yaml"

        # update/append appVersion in Chart.yaml
        if grep "appVersion:" "$dir/Chart.yaml"; then
            sed -i "$dir/Chart.yaml" -e "s/appVersion:.*/appVersion: ${APP_VERSION}/"
        else
            echo "appVersion: ${APP_VERSION}" >> "$dir/Chart.yaml"
        fi
        cat "$dir/Chart.yaml"
    else
        echo "WARN: Unable to set global.appVersion in $dir/Chart.yaml - the resulting Chart may not reference a specific image as a result"
    fi
fi

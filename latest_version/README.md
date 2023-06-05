# latest_version

Set of tools to find the latest stable version of a docker image, helm chart, or Python module.

## update_external_versions

Most CMS repos will only interact with the [update_external_versions.sh](update_external_versions.sh) tool, which looks for update_external_versions.conf in its current directory when it is being run. If that file is not found, the tool does nothing and exits with return code 0.

A template of what that file looks like is provided here in [update_external_versions.conf.template](update_external_versions.conf.template)

The sample configuration file and the header of the tool provide details on how exactly they work.

## latest_version

[latest_version.sh](latest_version.sh) and [latest_version.py](latest_version.py) are the tools which do most of the actual work.

update_external_versions.sh reads the configuration file and makes calls to latest_version.sh

In turn, latest_version.sh does some work and makes calls to latest_version.py

This is done just to logically break up the individual units of work.

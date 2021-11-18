#!/usr/bin/env python3

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

"""
usage: update_appversion.py <chart_directory> <app_version>
 
In the specified chart directory:
1) Changes/sets the global appVersion field in values.yaml to
   the specified app version
2) Changes/sets the appVersion field in Chart.yaml to the specified version.
"""

import argparse
from pathlib import Path
# Use ruamel because it preserves comments
from ruamel.yaml import YAML
import sys

def valid_chart_dir(argstring):
    dir_path = Path(argstring)
    if not dir_path.exists():
        raise argparse.ArgumentTypeError("Path does not exist")
    elif not dir_path.is_dir():
        raise argparse.ArgumentTypeError("Path exists but is not a directory")
    for file_name in [ "Chart.yaml", "values.yaml" ]:
        file_path = dir_path / file_name
        if not file_path.exists():
            raise argparse.ArgumentTypeError(f"{file_path} not found")
        elif not file_path.is_file():
            raise argparse.ArgumentTypeError(
                f"{file_path} found but it is not a regular file")
        # Finally, make sure we can open it
        try:
            file_path.open("rt")
        except Exception as exc:
            raise argparse.ArgumentTypeError(
                f"Error opening {file_path}: {exc}") from exc
    return dir_path

def nonempty_string(argstring):
    if argstring:
        return argstring
    raise argparse.ArgumentTypeError("appVersion may not be blank")

def parse_args():
    parser = argparse.ArgumentParser(
        description="Tool to set appVersion fields in Chart.yaml and values.yaml")
    parser.add_argument("chart_dir", 
        metavar="<chart_directory>", 
        required=True,
        type=valid_chart_dir,
        help="Directory containing Chart.yaml and values.yaml")
    parser.add_argument("app_version", 
        metavar="<app_version>", 
        required=True,
        type=nonempty_string,
        help="Value for appVersion fields")
    parser.parse_args()
    return args.chart_dir, args.app_version

def main(chart_dir, app_version):
    # Use 'rt' type so we preserve comments in the files
    yaml = YAML(typ="rt")
    # Force block-style output
    yaml.default_flow_style = False

    # values.yaml
    values_yaml_file = chart_dir / "values.yaml"
    print(f"Loading {values_yaml_file}")
    with values_yaml_file.open("rt"):
        values_yaml_data = yaml.load(values_yaml_file)
    # Set the global appVersion to the specified version
    try:
        values_yaml_data["global"]["appVersion"] = app_version
        print(
            f"Setting global appVersion to {app_version} in {values_yaml_file}")
    except KeyError:
        # If there isn't a global stanza, we'll create it
        values_yaml_data["global"] = { "appVersion": app_version }
        print(
            f"Creating global stanza and setting global appVersion to {app_version} in {values_yaml_file}")
    # Now write back to the file
    yaml.dump(values_yaml_data, values_yaml_file)

    # Chart.yaml
    chart_yaml_file = chart_dir / "Chart.yaml"
    print(f"Loading {chart_yaml_file}")
    with chart_yaml_file.open("rt"):
        chart_yaml_data = yaml.load(chart_yaml_file)
    # Set appVersion to the specified version
    chart_yaml_data["appVersion"] = app_version
    print(f"Setting appVersion to {app_version} in {chart_yaml_file}")
    # Now write back to the file
    yaml.dump(chart_yaml_data, chart_yaml_file)

    print(f"Completed updating appVersion in {values_yaml_file} and {chart_yaml_file}")

if __name__ == "__main__":
    chart_dir, app_version = parse_args()
    main(chart_dir, app_version)
    sys.exit(0)

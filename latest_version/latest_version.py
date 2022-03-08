#!/usr/bin/env python3
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
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
# Usage: latest_version.py [--type image_type] [--nonstandard-versions-okay]
#                          [[--major major# [--minor minor#]]
#                          --file input_file --image image_name {--docker | --helm}
#
# Parse the input_file (json file if docker, yaml if helm)
# Find all versions of the specified image, filtering for major and minor number if specified

# image_type is used to filter stable vs unstable on algol60
# For docker JSON files, "<type>/" will be prepended to the image name in the manifest listing.
# For helm YAML files, "<type>/" will be prepended to the image name in the url field for an image

# If --nonstandard-versions-okay is not specified, then the version strings will be
# filtered to make sure they match the format described in update_versions.sh (essentially SemVer 2.0,
# with a minor exception)

# Print the version string of the latest version and exit code 0
# Print error message and exit code 1 if there is a problem with any of the above

import functools
import re
import sys

# Version regular expression patterns

NUM_PATTERN="0|[1-9][0-9]*"

# The basic pattern is 3 nonnegative integers without leading 0s, separated by dots
BASE_VPATTERN="(?:{NUM})[.](?:{NUM})[.](?:{NUM})".format(NUM=NUM_PATTERN)

# A pre-release identifier is any of the following:
# - Any string of 1 or more digits with no leading 0s
# - Any string consisting of 1 or more alphanumeric characters or hyphens, with at least 1 non-numeric character
PID_PATTERN="(?:{NUM}|[-a-zA-Z0-9]*[-a-zA-Z][-a-zA-Z0-9]*)".format(NUM=NUM_PATTERN)

# A pre-release version is one or more dot-separated pre-release identifiers
PRV_PATTERN="{PID}(?:[.]{PID})*".format(PID=PID_PATTERN)

# A build identifier is any of the following:
# - Any string consisting of 1 or more alphanumeric characters or hyphens
BID_PATTERN="[-a-zA-Z0-9][-a-zA-Z0-9]*"

# Build metadata is one or more dot-separated build identifiers
BMD_PATTERN="{BID}(?:[.]{BID})*".format(BID=BID_PATTERN)

# The full version string must begin with the base pattern
# After that is an optional hyphen and pre-release version
# After those is an optional plus (or underscore) and build-metadata
VPATTERN_PREFORMAT=BASE_VPATTERN + "(?:-{PRV})?" + "(?:[+_]{BMD})?"
VPATTERN = VPATTERN_PREFORMAT.format(PRV=PRV_PATTERN, BMD=BMD_PATTERN)

SEMVER_REGEX = re.compile(VPATTERN)

def print_err(s):
    print("latest_version.py: ERROR: " + s, file=sys.stderr)

def print_warn(s):
    print("latest_version.py: WARNING: " + s, file=sys.stderr)

def err_exit(*msgs):
    for m in msgs:
        print_err(m)
    sys.exit(1)

def validate_majorminor(n):
    try:
        i = int(n)
    except ValueError:
        err_exit("Major/minor numbers must be integers. Invalid: %s" % n)
    if i < 0:
        err_exit("Major/minor numbers must be nonnegative integers. Invalid: %d" % i)
    return i

def parse_parameters():
    argument_to_parameter_map = {
        "--nonstandard-versions-okay": "no_version_format_filter",
        "--type": "image_type",
        "--major": "major",
        "--minor": "minor",
        "--file": "input_file",
        "--image": "image_name",
        "--docker": "docker_helm",
        "--helm": "docker_helm" }
    params = { pname: None for pname in argument_to_parameter_map.values() }
    cmd_line_args = sys.argv[1:]
    i=0
    while i < len(cmd_line_args):
        arg = cmd_line_args[i]
        i+=1
        try:
            param_name = argument_to_parameter_map[arg]
        except KeyError:
            err_exit("Unrecognized flag: " + arg)
        if params[param_name] != None:
            err_exit("Duplicate or conflicting flag: " + arg)
        elif arg in { "--docker", "--helm" }:
            # Just strip off the leading --
            params[param_name] = arg[2:]
            continue
        elif arg == "--nonstandard-versions-okay":
            params[param_name] = True
            continue
        try:
            flag_arg = cmd_line_args[i]
        except IndexError:
            err_exit("%s flag requires an argument" % arg)
        i+=1
        if arg in { "--major", "--minor" }:
            params[param_name] = validate_majorminor(flag_arg)
        elif not flag_arg:
            err_exit("%s flag cannot have a blank argument" % arg)
        else:
            params[param_name] = flag_arg

    # Finally, make sure we got required arguments
    if params["minor"] != None and params["major"] == None:
        err_exit("A minor number may not be specified without a major number")
    elif params["input_file"] == None:
        err_exit("Input file must be specified")
    elif params["image_name"] == None:
        err_exit("Image name must be specified")
    elif params["docker_helm"] == None:
        err_exit("--docker or --helm must be specified")
    return params

def is_int(s):
    try:
        int(s)
        return True
    except ValueError:
        return False

def compare_identifiers(a, b):
    if is_int(a) and is_int(b):
        i = int(a)
        j = int(b)
        if i > j:
            return 1
        elif j > i:
            return -1
        else:
            return 0
    elif is_int(a):
        # a is an int, b is not
        # so semver says that b > a
        return -1
    elif is_int(b):
        # the reverse, so a > b
        return 1
    # Neither a nor b are ints, so just go by ASCII order
    if a > b:
        return 1
    elif b > a:
        return -1
    else:
        return 0

def remove_build(s):
    # The build metadata string may be separated using either an underscore or a plus
    try:
        return s[:s.index('+')]
    except ValueError:
        # No + was found. Try _
        try:
            return s[:s.index('_')]
        except ValueError:
            # This means there was no build metadata to remove
            return s

def get_version_and_prerelease(s):
    try:
        i = s.index('-')
        return s[:i], s[i+1:]
    except ValueError:
        return s, None

def compare_versions(a, b, prStripped=False):
    # First, strip away build metadata, as this is to be ignored when doing comparisons
    a = remove_build(a)
    b = remove_build(b)
    if not prStripped:
        aVersion, aPrerelease = get_version_and_prerelease(a)
        bVersion, bPrerelease = get_version_and_prerelease(b)
    else:
        # This is a recursive call comparing prerelease versions, so we don't need to split that
        aVersion, aPrerelease = a, None
        bVersion, bPrerelease = b, None
    
    aVersionIds = aVersion.split('.')
    bVersionIds = bVersion.split('.')
    for aId, bId in zip(aVersionIds, bVersionIds):
        c = compare_identifiers(aId, bId)
        if c != 0:
            return c
    # If the Ids are all equal so far, if a or b has some Ids left over, then that
    # version is considered higher
    if len(aVersionIds) > len(bVersionIds):
        return 1
    elif len(bVersionIds) > len(aVersionIds):
        return -1

    # Ok, in this case we compare pre-release versions
    if aPrerelease == None and bPrerelease == None:
        # Nothing left to compare
        return 0
        
    # By semver, a version with a pre-release version is lower than one without it
    if aPrerelease == None and bPrerelease != None:
        return 1
    elif bPrerelease == None and aPrerelease != None:
        return -1

    # If both a and b pre-release versions are not none, then we compare those as version
    # strings
    return compare_versions(aPrerelease, bPrerelease)

params = parse_parameters()
docker_helm = params["docker_helm"]
input_file = params["input_file"]
image_name = params["image_name"]
image_type = params["image_type"]
major = params["major"]
minor = params["minor"]
version_format_filter = (params["no_version_format_filter"] != True)

if major == None:
    version_prefix = ""
else:
    version_prefix = str(major)
    if minor != None:
        version_prefix += "." + str(minor)

# The first thing we will do is generate a list of ALL versions of our chosen image
if docker_helm == "docker":
    import json
    with open(input_file, "rt") as f:
        docker_data = json.load(f)
    manifests = docker_data["manifests"]
    # The manifests are strings of the form 
    # image_name/version/manifest.json              (arti.dev format)
    # or
    # image_type/image_name/version/manifest.json   (algol60 format)
    #
    # For this tool, we assume that if image_type has been specified to us, then we're dealing with
    # the second format, otherwise we are dealing with the first format

    if image_type == None:
        # Now we just look for manifest strings that begin with image_name/
        # and extract the second /-separated field
        image_prefix = image_name + "/"
        field_index = 1
    else:
        # look for manifest strings that begin with image_type/image_name/
        # and extract the third /-separated field
        image_prefix = image_type + "/" + image_name + "/"
        field_index = 2

    all_versions = [ m.split('/')[field_index] for m in manifests if m.find(image_prefix) == 0 ]
else:
    import yaml
    with open(input_file, "rt") as f:
        helm_data = yaml.safe_load(f)
    entries = helm_data["entries"]
    try:
        my_image_entries = entries[image_name]
    except KeyError:
        my_image_entries = list()
    # If an image_type was specified, we need to filter this list further, only including
    # entries whose url field contains at least 1 url with "/image_type/image_name/" in them
    if image_type != None:
        url_substring = "/" + image_type + "/" + image_name + "/"
        my_image_entries = [ entry for entry in my_image_entries if any(
            url_substring in url for url in entry["urls"]) ]
    # my_image_entries is now a list of dicts that have info on each version of our
    # image. So we need to turn that into a list of just version strings
    all_versions = [ mie["version"] for mie in my_image_entries ]

if image_type == None:
    label="entries"
else:
    label="%s entries" % image_type

if len(all_versions) == 0:
    if version_prefix:
        err_exit("No %s found for %s even before filtering for version %s" % (label, image_name, version_prefix))
    else:
        err_exit("No %s found for %s" % (label, image_name))
elif version_format_filter:
    # Filter out any versions which don't begin with #.#.# followed by 
    all_versions = [ ver for ver in all_versions if SEMVER_REGEX.fullmatch(ver) ]
    if len(all_versions) == 0:
        if version_prefix:
            err_exit("No %s found for %s after filtering nonstandard version formats (but before filtering for version %s)" % (label, image_name, version_prefix))
        else:
            err_exit("No %s found for %s after filtering nonstandard version formats" % (label, image_name))

if version_prefix:
    # Now we need to extract only those version strings which match our prefix
    # There are a few cases to consider:
    # 1) The version string is exactly equal to our version prefix
    # 2) The version string starts with our prefix followed by a period, because
    #    there are additional version fields
    # 3) The version string starts with our prefix followed by a dash, indicating
    #    a prelease id
    # 4) The version string starts with our prefix followed by a plus, indicating
    #    a build id
    #
    # So filter our list for only versions which meet one of the above criteria

    version_prefixes = [ version_prefix + c
                         for c in [ ".", "-", "+" ] ] 
    my_versions = [ v for v in all_versions
                   if v == version_prefix or
                   any(v.find(vp) == 0 for vp in version_prefixes) ]
    if len(my_versions) == 0:
        err_exit("No entries found for %s after filtering for version %s" % (image_name, version_prefix))
else:
    # This case is simple -- we want the entire version list
    my_versions = all_versions

my_versions.sort(key=functools.cmp_to_key(compare_versions))
print(my_versions[-1])
sys.exit(0)

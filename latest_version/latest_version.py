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

# Usage: latest_version.py {docker|helm} input_file image_name [[major# [minor#]]
#
# Parse the input_file (json file if docker, yaml if helm)
# Find all versions of the specified image, filtering for major and minor number if specified
# Print the version string of the latest version and exit code 0
# Print error message and exit code 1 if there is a problem with any of the above

import functools
import sys

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
    major = None
    minor = None
    args = sys.argv[1:]
    if not 3 <= len(args) <= 5:
        err_exit("Requires between 3 and 5 arguments, but received %d: %s" % (
            len(args), " ".join(args)))
    docker_helm, input_file, image_name = args[:3]
    if docker_helm not in { "docker", "helm" }:
        err_exit("First argument must be docker or helm")
    if not input_file:
        err_exit("Input file name must not be blank")
    if not image_name:
        err_exit("Image name must not be blank")
    if len(args) >= 4:
        major = validate_majorminor(args[3])
        if len(args) >= 5:
            minor = validate_majorminor(args[4])
    return docker_helm, input_file, image_name, major, minor

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
    try:
        return s[:s.index('+')]
    except ValueError:
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

docker_helm, input_file, image_name, major, minor = parse_parameters()

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
    # The manifests are strings of the form image_name/version/manifest.json

    # Now we just look for manifest strings that begin with image_name/
    # and extract the second /-separated field
    all_versions = [ m.split('/')[1] for m in manifests if m.find(image_name + "/") == 0 ]
else:
    import yaml
    with open(input_file, "rt") as f:
        helm_data = yaml.safe_load(f)
    entries = helm_data["entries"]
    try:
        my_image_entries = entries[image_name]
    except KeyError:
        my_image_entries = list()
    # my_image_entries is now a list of dicts that have info on each version of our
    # image. So we need to turn that into a list of just version strings
    all_versions = [ mie["version"] for mie in my_image_entries ]

if len(all_versions) == 0:
    if version_prefix:
        err_exit("No entries found for %s even before filtering for version %s" % (image_name, version_prefix))
    else:
        err_exit("No entries found for %s" % image_name)

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

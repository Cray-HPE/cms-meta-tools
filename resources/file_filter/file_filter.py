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

# Usage: file_filter.py <config-file-1> [<config-file-2>] ...
#
# 1) For each file, parse it and read in its include and exclude
# fields. Later files will overwrite values from fields in earlier files.
#
# 2) Build up a set of include and exclude rules from these include and exclude
# fields.
#
# 3) Reads a list of path+filenames from stdin
#
# 4) Filters them based on the includes & excludes from the yaml files
#
# 5) Prints to stdout any which make it through the filter

import re
import sys
import yaml

valid_fields = []
for s in [ "extensions", 
           "files", 
           "subfiles",
           "directories", 
           "subdirectories", 
           "filename_patterns", 
           "dirname_patterns", 
           "filepath_patterns", 
           "dirpath_patterns" ]:
    for ie in [ "include", "exclude" ]:
        valid_fields.append("%s_%s" % (ie, s))
        valid_fields.append("also_%s_%s" % (ie, s))

field_prog_lists = { f: [] for f in valid_fields }

def print_err(s):
    print("file_filter.py: ERROR: " + s, file=sys.stderr)

def err_exit(*msgs):
    for m in msgs:
        print_err(m)
    sys.exit(1)

# A file with extension ext is equivalent to filepath_pattern .*[.]ext$
def ext_to_re_prog(ext):
    fppat = ".*[.]" + ext + "$"
    return re.compile(fppat)

# A file fname is equivalent to fname$, since it is interpreted from
# the base of the repo
def file_to_re_prog(fname):
    fppat = fname + "$"
    return re.compile(fppat)

# subfiles just need to have (|.*/) put in front of them and $ after them
# to become filepath_patterns
def subfile_to_re_prog(fname):
    fppat = "(|.*/)" + fname + "$"
    return re.compile(fppat)

# Same for filename_patterns, except because they are patterns, the $ may already
# be there
def filename_pattern_to_re_prog(fnpat):
    fppat = "(|.*/)" + fnpat
    if fppat[-1] != "$":
        fppat += "$"
    return re.compile(fppat)

# For filepath patterns, only need to check for the trailing $
def filepath_pattern_to_re_prog(fppat):
    if fppat[-1] != "$":
        fppat += "$"
    return re.compile(fppat)

# A directory dname is interpreted from the base of the repo.
# Its equivalent filepath pattern is dname/.*$
def directory_to_re_prog(dname):
    fppat = dname + "/.*$"
    return re.compile(fppat)

# Same for dirpath patterns, except the $ may already be there
def dirpath_pattern_to_re_prog(dppat):
    fppat = dppat + "/.*"
    if fppat[-1] != "$":
        fppat += "$"
    return re.compile(fppat)

# subdirectory dname is equivalent to filepath_pattern (|.*/)dname/.*$
def subdirectory_to_re_prog(dname):
    fppat = "(|.*/)" + dname + "/.*$"
    return re.compile(fppat)

# same for dirname_patterns, except need to check for the trailing $
def dirname_pattern_to_re_prog(dname):
    fppat = "(|.*/)" + dname + "/.*"
    if fppat[-1] != "$":
        fppat += "$"
    return re.compile(fppat)

class ConfigParseException(Exception):
    pass

def get_reprog(field_name, s):
    # s is a string element in the field_name list
    if "_extensions" in field_name:
        return ext_to_re_prog(s)
    elif "_files" in field_name:
        return file_to_re_prog(s)
    elif "_subfiles" in field_name:
        return subfile_to_re_prog(s)
    elif "_filename_patterns" in field_name:
        return filename_pattern_to_re_prog(s)
    elif "_filepath_patterns" in field_name:
        return filepath_pattern_to_re_prog(s)
    elif "_directories" in field_name:
        return directory_to_re_prog(s)
    elif "_dirpath_patterns" in field_name:
        return dirpath_pattern_to_re_prog(s)
    elif "_subdirectories" in field_name:
        return subdirectory_to_re_prog(s)
    elif "_dirname_patterns" in field_name:
        return dirname_pattern_to_re_prog(s)
    # Should never get here, because we have previously vetted the field_name
    raise ConfigParseException("PROGRAMMING LOGIC ERROR: get_reprog: Unknown field name: %s" % field_name)

def parse_field(config_data, field_name, field_value):
    if not isinstance(field_value, list):
        raise ConfigParseException(
                "Field %s should be a list but it is type %s" % (field_name, type(field_value)))
    field_prog_lists[field_name] = list()
    for s in field_value:
        if not isinstance(s, str):
            raise ConfigParseException(
                "Field %s should be list of strings but an element is of type %s" % (field_name, type(s)))
        if len(s) == 0:
            raise ConfigParseException(
                "Field %s contains an empty string, which is not permitted" % field_name)
        try:
            field_prog_lists[field_name].append(get_reprog(field_name, s))
        except re.error as e:
            print_err(str(e))
            raise ConfigParseException(
                "Field %s contains an invalid string value: %s" % (field_name, s))

# First parse the config yaml files

if len(sys.argv) < 2:
    err_exit("At least one config file must be specified")

for config_file in sys.argv[1:]:
    try:
        with open(config_file, "rt") as f:
            config_data = yaml.safe_load(f)
    except FileNotFoundError:
        err_exit("File not found: %s" % config_file)
    except yaml.YAMLError as e:
        err_exit(
            str(e), 
            "YAML error parsing %s" % config_file)
    for field_name in valid_fields:
        try:
            field_value = config_data[field_name]
        except KeyError:
            continue
        try:
            parse_field(config_data, field_name, field_value)
        except ConfigParseException as e:
            err_exit(
                str(e),
                "Error parsing config file %s" % config_file)

# Now build our include and exclude patterns
# Internally they are all converted to filepath patterns

include_progs = list()
exclude_progs = list()
for (k, v) in field_prog_lists.items():
    if "include_" in k:
        include_progs.extend(v)
    elif "exclude_" in k:
        exclude_progs.extend(v)
    else:
        err_exit("PROGRAMMING LOGIC ERROR: k = %s" % k)

if not include_progs:
    print_err("No include patterns specified, so no files will be included for processing")
    sys.exit(0)

for line in sys.stdin:
    line = line.rstrip()
    if not any(p.match(line) for p in include_progs):
        # This meets none of our include criteria, so skip it
        continue
    if any(p.match(line) for p in exclude_progs):
        # This meets at least one of our exclude criteria, so skip it
        continue
    # Meets at least one include criterion and none of our exclude criteria,
    # so print it
    print(line)

sys.exit(0)

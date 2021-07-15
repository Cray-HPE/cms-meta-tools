# file_filter

Helper tool for other tools in the cms-meta-tools repo.

Reads path+filenames from standard input (one per line) and prints out those which
make it through the filtering process. The filters are determined by a list of
config files that are passed into the file_filter.py tool as arguments. These
files are parsed in order, with later files possibly overriding values from
earlier files. See [file_filter_config.yaml.template](file_filter_config.yaml.template)
for details on these config files and how the tool does its filtering based
on them.

The location this tool is called from does not matter. It does not actually try to
look at any of the files being read in from standard input. Its matching is based solely
on their path and filenames.

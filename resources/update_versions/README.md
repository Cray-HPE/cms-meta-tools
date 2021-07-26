# update_versions.sh

Replaces version placeholder strings (e.g. @VERSION@) in files in a repo with the actual version.

Script is called without arguments from the root of the repo.

It requires that a config file named `update_versions.conf` be present at the root of the repo. This
file determines how the replacement process happens. 
See [update_versions.conf.template](update_versions.conf.template) for details on this.

Displays the replacements as they happen, showing the diffs for all altered files.

Exits 0 on success, 1 otherwise.

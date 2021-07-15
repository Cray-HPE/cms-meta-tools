# copyright_license_check.sh

Verifies that files in a repo have copyright and license headers, if required.

Script is called without arguments from the root of the repo to be checked.

The default config file ([copyright_license_check.yaml](copyright_license_check.yaml))
is located in the same directory as the script. If a config file with the same name is
found in the root of the repo, any conflicting values it has will override those from
the default config file.

These config files are used to determine which files in the repo should be
checked for copyright and license. See the default config file for more
details on this. The [file_filter](../file_filter) tool is used to select the files
from the output of the output of the `git ls-files --empty-directory` command.

Displays a list of files being checked, indicating whether or not they are missing
copyright or license.

Exits with status code 0 if success, 1 otherwise.

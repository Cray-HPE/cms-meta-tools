# go_lint.sh

Verifies that Go files in a repo pass a linting check (by running `gofmt -s -l`
against them). 

Script is called without arguments from the root of the repo to be checked.

The default config file ([go_lint.yaml](go_lint.yaml))
is located in the same directory as the script. If a config file with the same name is
found in the root of the repo, any conflicting values it has will override those from
the default config file.

These config files are used to determine which files in the repo should be
checked. See the default config file for more
details on this. The [file_filter](../file_filter) tool is used to select the files
from the output of the output of the `git ls-files --empty-directory` command.

Displays a list of files being checked, indicating whether or not they passed.

Exits with status code 0 if success, 1 otherwise.

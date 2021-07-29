# CMS Meta-Tools

CMS team meta-tools repository. This collection of tools is used when building our other repos, but is not included as part of the product.

## How to use in your repo

For most CMS repos it will suffice to follow the instructions in the [sample_scripts](sample_scripts) folder.

## Meet the team

### [copyright_license_check](copyright_license_check)

Verifies that files in a repo have copyright and license headers, if required.

### [file_filter](file_filter)

Filters lists of files. Helper tool for other tools in this repo.

### [go_lint](go_lint)

Verifies that Go files in a repo pass a linting with `gofmt`

### [latest_version](latest_version)

Finds the latest version of a docker or helm image on arti.dev.cray.com

### [update_versions](update_versions)

Replaces placeholder strings in repo files with version strings read in
from other repo files.

## Versioning
Use [SemVer](http://semver.org/). The version is located in the [.version](.version) file. Any files
in the repo which need this version read it directly from this file.

## Copyright and License
This project is copyrighted by Hewlett Packard Enterprise Development LP and is under the MIT
license. See the [LICENSE](LICENSE) file for details.

When making any modifications to a file that has a Cray/HPE copyright header, that header
must be updated to include the current year.

When creating any new files in this repo, if they contain source code, they must have
the HPE copyright and license text in their header, unless the file is covered under
someone else's copyright/license (in which case that should be in the header). For this
purpose, source code files include Dockerfiles, Ansible files, and shell scripts. It does
**not** include Jenkinsfiles, OpenAPI/Swagger specs, or READMEs.

When in doubt, provided the file is not covered under someone else's copyright or license, then
it does not hurt to add ours to the header.

# git_info.sh

This is used by repos with dynamic versioning to include information in its build artifacts
that make it easier to trace them back to the code which produced them.

For RPMs, this involves adding git build information to the changelog.

For helm charts, this involves adding git build as annotations metadata.

For docker containers, this involves copying the information into the container root
in a small text file.

Exits with status code 0 if success, 1 otherwise. If it finds no configuration file in
the repo, it does nothing and exits with return code 0.

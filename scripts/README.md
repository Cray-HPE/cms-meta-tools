# Scripts

These are scripts that use the cms-meta-tools utilities to perform common CMS build functions. If you use
the [cms-meta-tools sample scripts](../sample_scripts) in your repo, they are wrappers that ultimately
call these scripts.

<a name=#runBuildPrep.sh></a>
## [runBuildPrep.sh](runBuildPrep.sh)

Calls the [update_versions](../update_versions) and [update_external_versions](../latest_version) tools. 
Both of these tools do nothing unless they find their corresponding config file in your repo.

<a name=#runLint.sh></a>
## [runLint.sh](runLint.sh)

Calls the [copyright_license_check](../copyright_license_check) and 
[go_lint](../go_lint) tools. These tools do not require a config file in
your repo to run, but if such a config file is present, it can be used to alter their default
behavior. Without a config file they use sensible defaults that will work for most repos.

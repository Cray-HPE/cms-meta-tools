# Sample Scripts

These are scripts you can copy to your repo in order to use cms-meta-tools functions. In almost
all cases you can copy them as-is with no edits required.

## How to use them in a CMS repo

1. Copy all of the scripts in this directory into the root of your repo and make them executable.

2. The first step of your repo build should run runBuildPrep.sh

3. The second step of your repo build sahould run runLint.sh

That's it. If you need to customize the behavior of any of the tools being used, see the individual
tool for details on how to provide it with a configuration file, or look at another CMS repo which
is already using them.

## Sample Script Listing

### [install_cms_meta_tools.sh](install_cms_meta_tools.sh)

This script is required for any of the other scripts to work. Its job is to find the latest stable
version of the cms-meta-tools RPM and extract its contents into a subdirectory of your current
directory. Even though cms-meta-tools is packaged as an RPM, 
**it does not install itself onto the global system**.

### [runBuildPrep.sh](runBuildPrep.sh)

Wrapper that calls the cms-meta-tools [runBuildPrep.sh](../scripts/README.md#runBuildPrep.sh) script.
It exits with a non-0 exit code on error.

### [runLint.sh](runLint.sh)

Wrapper that calls the cms-meta-tools [runLint.sh](../scripts/README.md#runLint.sh) script.
It exits with a non-0 exit code on error.

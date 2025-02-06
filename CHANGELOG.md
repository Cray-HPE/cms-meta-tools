# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Created `buildCsmRpms`, `runCMTScript`, and `copyCMTFiles` groovy scripts
- Created `build_rpms.sh` script
- Created `publishCsmDockerImageIgnoreSnykPythonWerkzeug6808933` to ignore
  [`SNYK-PYTHON-WERKZEUG-6808933`](https://security.snyk.io/vuln/SNYK-PYTHON-WERKZEUG-6808933)
  when publishing a Docker image.

## [3.5.3] - 2024-09-13
### Changed
- Don't install Python modules from artifactory

## [3.5.2] - 2024-08-19
### Added
- Create generic `cloneGitRepo` script.

### Changed
- Modify `CloneCMSMetaTools` script to use new `cloneGitRepo` script.

## [3.5.1] - 2024-08-02
### Changed
- Checkout `master` branch when cloning

## [3.5.0] - 2024-08-02
### Changed
- Modify `git_info` tool to allow for Dockerfiles that have uppercase `as` in their FROM lines
- `cloneCMSMetaTools.groovy`: After cloning, do a git log to show the head of the cloned repo

## [3.4.0] - 2024-07-29
### Changed
- Use GitVersion v5 docker image instead of relying on whatever version is installed in build environment

### Removed
- Remove modifications from v3.3 to handle gitversion v6

## [3.3.0] - 2024-07-25
### Changed
- Disabled concurrent Jenkins builds on same branch/commit
- Added build timeout to avoid hung builds
- Modify setVersions to check version of gitversion and update config file to handle it, if needed

## [3.2.0] - 2023-06-26
### Changed
- Added logic to setVersions function to ensure that for repos using gitversion, all unstable
  artifacts will have versions that include a prerelease tag.

## [3.1.0] - 2023-06-05
### Added
- Added support for stable Python modules to update_external_versions

## [3.0.0] - 2022-12-12
### Changed
- Convert from vendor specific Artifactory API to Docker v2 API.
- Authentiction is now mandatory
- Cleanup of temporary file
- Spelling corrections.

## [2.1.0] - 2022-08-10
### Changed
- Convert to gitflow/gitversion.


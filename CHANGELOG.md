# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Update license text to comply with automatic license-check tool.

## [3.0.3] - 2022-03-11

### Added

- Added support for `CF_IMPORT_FORCE_EXISTING_BRANCH` from cf-gitea-import v1.6.0.

## [3.0.2] - 2022-03-04

### Changed

- Switch build prep workflow to use GH ubuntu runner instead of self-hosted for security reasons

## [3.0.1] - 2022-02-11

### Added

- Added dependabot for Github Actions
- Added GitVersion.yml config file

### Changed

- Fixed CHANGELOG.md to point to old repo for pre-v2.0.0 releases

## [3.0.0] - 2022-02-11

### Changed

- Converted repository to just cray-import-config, using GH actions and workflows to build (CASMCMS-7812)
- Converted repository to CSM gitflow development process (CASMCMS-7812)

### Removed

- Chart no longer builds via Jenkins

## [2.0.0] - 2021-11-29

### Added

- See https://github.com/Cray-HPE/cray-product-install-charts for this release and prior.


[Unreleased]: https://github.com/Cray-HPE/cray-image-config/compare/v3.0.1...HEAD

[3.0.1]: https://github.com/Cray-HPE/cray-image-config/compare/v3.0.0...v3.0.1

[3.0.0]: https://github.com/Cray-HPE/cray-image-config/compare/v2.0.0...v3.0.0

[2.0.0]: https://github.com/Cray-HPE/cray-product-install-charts/releases

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
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


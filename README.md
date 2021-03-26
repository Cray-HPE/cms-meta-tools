# cray-product-install-charts

This repository contains base charts used in the product install workflow.

See the [developer guide](https://connect.us.cray.com/confluence/display/CASM/Shasta+Product+Installation+Developer+Guide) for more information.

## Contributing Charts

Add charts to their own directory in the charts subdirectory and maintain their
version with SemVer.

Create a branch from the default (master) branch and submit a PR. When the PR is merged and
the base chart is ready to be released for use, merge the default branch to `release/stable`.

## Versioning

Charts are versioned in their `Chart.yaml` file. Released charts for public consumption to should
only come from chart versions in the release/stable branch of this repository.

## Releases

The charts in this repository are subcharts and do not follow the same versioning workflow as most other software.
Charts that are built in master/dev/feature/bugfix branches have versions that are appended by the build pipeline
with a build date and git hash, e.g. `cray-import-config-0.0.2-20201023091619+34aaf71`. However, branches with
`release/` in their name will only use the Charts SemVer version, e.g. `cray-import-config-0.0.2`.

Users of subcharts should only reference released versions in their chart's requirements file.

When a subchart is ready to be released to consumers, merge master to `release/stable` and then
communicate to users about the new versions.

Do not use charts from any branch except `release/stable`.

Do not create `release/[product]-[version]` branches in this repository as they do not have meaning for base charts.

## Contributors

* Randy Kleinman (randy.kleinman@hpe.com)

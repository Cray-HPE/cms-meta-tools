/*
 *
 *  MIT License
 *
 *  (C) Copyright 2021-2023 Hewlett Packard Enterprise Development LP
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included
 *  in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 *  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 *  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *  OTHER DEALINGS IN THE SOFTWARE.
 *
 */

def call() {
    def basever
    def chartver
    def dockerver
    def gitversion = false
    def prereleasetag
    def rpmrel
    def sha
    def stablebuild = env.IS_STABLE
    def stablestring

    /// Need the CSM shared library for the getDockerBuildVersion function
    echo "Loading csm-shared-library, if it is not already loaded (an error message about this can be ignored)"
    library 'csm-shared-library'
    
    if (stablebuild instanceof String) {
        stablebuild = stablebuild.toBoolean()
    }

    if (stablebuild) {
        stablestring = "stable"
    } else {
        stablestring = "unstable"
    }
    echo "Writing '${stablestring}' to .stable"
    writeFile(file: ".stable", text: stablestring)

    ///////////////////
    // Base version
    ///////////////////
    if (fileExists('.version')) {
        // Using static versioning
        echo ".version file exists -- using static versioning"
        echo "Reading base version from .version"
        basever = readFile('.version').trim()
        echo "Base version is ${basever}"
    } else
    if (fileExists('GitVersion.yml')) {
        // Using gitversion versioning
        gitversion = true
        echo "GitVersion.yml file exists -- using gitversion versioning"
        echo "Ensuring local develop and master branches"
        echo "Current branch is ${env.GIT_BRANCH}"
        branches = sh(returnStdout: true, script: "git branch -r --color=never").split("\n").collect{it.strip()}
        if ( branches.find{it=="origin/main"} ) {
            if ( env.GIT_BRANCH != "main" ) {
                sh "git branch main --track origin/main"
            }
        } else if ( branches.find{it=="origin/master"} ) {
            if ( env.GIT_BRANCH != "master" ) {
                sh "git branch master --track origin/master"
            }
        } else {
            error "Cloned repository is missing master or main branch, required for gitversion functionality"
        }
        if ( branches.find{it=="origin/develop"} ) {
            if ( env.GIT_BRANCH != "develop" ) {
                sh "git branch develop --track origin/develop"
            }
        } else {
            error "Cloned repository is missing develop or main branch, required for gitversion functionality"
        }

        echo "Reading base version from gitversion"
        basever = sh(returnStdout: true, script: "gitversion /output json /showvariable MajorMinorPatch /nonormalize").trim()

        echo "Reading PreReleaseTag from gitversion"
        prereleasetag = sh(returnStdout: true, script: "gitversion /output json /showvariable PreReleaseTag /nonormalize").trim()
        echo "PreReleaseTag is '${prereleasetag}'"

        // If we are building an unstable artifact, then we want to ensure that there is a prerelease tag.
        // The only time this will not be the case is if this commit has been tagged with a semver version string
        // that lacks a prerelease tag itself (e.g. v2.5.0). In this case, we want to modify the tags so that gitversion
        // generates a version with a prerelease tag.
        if ((!stablebuild) && (prereleasetag == "")) {
            echo "Unstable build with no prerelease tag is undesirable."

            // Get the list of tags on this commit
            gittags = sh(returnStdout: true, script: "git tag --points-at").trim()
            echo "Found these tag(s) on this commit: ${gittags}"

            // Delete the tags on this commit locally
            for (gittag in gittags.split()) {
                echo "Deleting git tag: '${gittag}'"
                sh(script: "git tag -d ${gittag}")
            }

            // Add a new tag: current_version-unstable
            newgittag = "${basever}-unstable"
            echo "Tagging current commit '${newgittag}'"
            sh(script: "git tag ${newgittag}")

            // Re-read the base version and pre-release tags
            echo "Reading base version from gitversion"
            basever = sh(returnStdout: true, script: "gitversion /output json /showvariable MajorMinorPatch /nonormalize").trim()
            echo "Writing version '${basever}' to .version"
            writeFile(file: ".version", text: basever)

            echo "Reading PreReleaseTag from gitversion"
            prereleasetag = sh(returnStdout: true, script: "gitversion /output json /showvariable PreReleaseTag /nonormalize").trim()
            echo "PreReleaseTag is '${prereleasetag}'"

            // The above tagging gymmastics should prevent this, but as a last resort, add -unstable prerelease tag
            if (prereleasetag == "") {
                prereleasetag = "unstable"
                echo "Manually overriding PreReleaseTag to '${prereleasetag}'"
            }

            // While it should not matter, let's tidy up and put the local git tags back the way that we found them.
            echo "Deleting git tag: '${newgittag}'"
            sh(script: "git tag -d ${newgittag}")

            for (gittag in gittags.split()) {
                echo "Recreating git tag: '${gittag}'"
                sh(script: "git tag ${gittag}")
            }
        } else {
            echo "Writing version '${basever}' to .version"
            writeFile(file: ".version", text: basever)
        }

        echo "Reading ShortSha from gitversion"
        sha = sh(returnStdout: true, script: "gitversion /output json /showvariable ShortSha /nonormalize").trim()
        echo "Sha is '${sha}'"
    } else {
        // Using dynamic versioning
        echo "No .version file exists -- using dynamic versioning"
        echo "Generating base version dynamically"
        basever = sh(returnStdout: true, script: "./cms_meta_tools/version.py").trim()
        echo "Base version is ${basever}"

        echo "Writing base version to .version"
        writeFile(file: ".version", text: basever)
    }

    ///////////////////
    // Docker version and Chart version
    ///////////////////
    if (gitversion) {
        echo "Generating Docker and Chart versions using gitversion data"
        dockerver = basever
        chartver = basever
        // We construct our version string using the information we got from gitversion.
        if (prereleasetag != "") {
            echo "Appending prereleasetag to Docker and Chart versions"
            dockerver = dockerver + "-" + prereleasetag
            chartver = chartver + "-" + prereleasetag
        } else {
            echo "prereleasetag is empty -- not appending it to Docker and Chart versions"
        }
        // Only use the sha for unstable artifacts
        if ((!stablebuild) && (sha != "")) {
            echo "Appending Sha to Docker and Chart versions"
            dockerver = dockerver + "_" + sha
            chartver = chartver + "+" + sha
        } else {
            echo "stable build or sha is empty -- not appending sha to Docker and Chart versions"
        }
        echo "Chart version is ${chartver}"
        echo "Docker version is '${dockerver}'"
    } else {
        echo "Calling getDockerBuildVersion to get docker version"
        dockerver = getDockerBuildVersion(isStable: stablebuild)
        echo "Docker version is ${dockerver}"

        echo "Converting docker version string to chart version string"
        chartver = dockerver.replaceAll("_", "+")
        echo "Chart version is ${chartver}"
    }

    echo "Writing docker version to .docker_version"
    writeFile(file: ".docker_version", text: dockerver)

    echo "Writing chart version to .chart_version"
    writeFile(file: ".chart_version", text: chartver)

    ///////////////////
    // RPM version and release
    ///////////////////
    // RPM versions and releases cannot contain the - character.
    // The base version will never have one, so that is our RPM version (thus we can use the regular .version file for that).
    // The RPM release will be the metadata+sha, except with dahses replaced by ~.
    // If no prerelease tag exists, it will default to 1 for the purposes of the RPM release field.
    rpmrel = "1"
    if (gitversion) {
        // We construct our RPM release string using the information we got from gitversion.
        if (prereleasetag != "") {
            echo "Basing RPM release on prereleasetag"
            rpmrel = prereleasetag.replaceAll("-", "~")
        }
        // Only use the sha for unstable artifacts
        if ((!stablebuild) && (sha != "")) {
            echo "Appending sha to RPM release"
            rpmrel = rpmrel + "+" + sha.replaceAll("-", "~")
        }
    }

    echo "RPM release is ${rpmrel}"
    echo "Writing RPM release to .rpm_release"
    writeFile(file: ".rpm_release", text: rpmrel)

    ///////////////////
    // Versions for other artifact types
    ///////////////////
    // The base version string is also what is used for Python modules, which is
    // why there are no .xxxx_version files generated for those
}

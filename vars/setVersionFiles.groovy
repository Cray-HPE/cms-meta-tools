/*
 *
 *  MIT License
 *
 *  (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
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
    def gitversion = false
    def prereleasetag
    def sha
    def chartver
    def dockerver
    def rpmrel

    /// Need the CSM shared library for the getDockerBuildVersion function
    echo "Loading csm-shared-library, if it is not already loaded (an error message about this can be ignored)"
    library 'csm-shared-library'

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
        echo "Writing version '${basever}' to .version"
        writeFile(file: ".version", text: basever)

        echo "Reading PreReleaseTag from gitversion"
        prereleasetag = sh(returnStdout: true, script: "gitversion /output json /showvariable PreReleaseTag /nonormalize").trim()
        echo "PreReleaseTag is '${prereleasetag}'"

        echo "Reading Sha from gitversion"
        sha = sh(returnStdout: true, script: "gitversion /output json /showvariable Sha /nonormalize").trim()
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
        dockerver = basever
        chartver = basever
        // Using gitversion. In this case, we construct our version string using the information we got from gitversion.
        if (prereleasetag != "") {
            echo "Appending prereleasetag to Docker and Chart versions"
            dockerver = dockerver + "-" + prereleasetag
            chartver = chartver + "-" + prereleasetag
        }
        if (sha != "") {
            echo "Appending Sha to Docker and Chart versions"
            dockerver = dockerver + "_" + sha
            chartver = chartver + "+" + sha
        }
        echo "Chart version is ${chartver}"
        echo "Docker version is '${dockerver}'"
    } else {
        echo "Calling getDockerBuildVersion to get docker version"
        dockerver = getDockerBuildVersion(isStable: env.IS_STABLE)
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
        // Using gitversion. In this case, we construct our version string using the information we got from gitversion.
        if (prereleasetag != "") {
            echo "Basing RPM release on prereleasetag"
            rpmrel = prereleasetag.replaceAll("-", "~")
        }
        if (sha != "") {
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

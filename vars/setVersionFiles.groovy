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
    def ver
    def chartver
    def dockerver
    def rpmver
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
        ver = readFile('.version').trim()
        echo "Base version is ${ver}"    
    } else
    if (fileExists('GitVersion.yml')) {
        // Using gitversion versioning
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
        ver = sh(returnStdout: true, script: "gitversion /output json /showvariable SemVer /nonormalize").trim()
        echo "Writing version '${ver}' to .version"
        writeFile(file: ".version", text: ver)
    } else {
        // Using dynamic versioning
        echo "No .version file exists -- using dynamic versioning"
        echo "Generating base version dynamically"
        ver = sh(returnStdout: true, script: "./cms_meta_tools/version.py").trim()
        echo "Base version is ${ver}"

        echo "Writing base version to .version"
        writeFile(file: ".version", text: ver)
    }

    ///////////////////
    // Docker version
    ///////////////////
    echo "Calling getDockerBuildVersion to get docker version"
    dockerver = getDockerBuildVersion(isStable: env.IS_STABLE)
    echo "Docker version is ${dockerver}"

    echo "Writing docker version to .docker_version"
    writeFile(file: ".docker_version", text: dockerver)

    ///////////////////
    // Chart version
    ///////////////////
    echo "Converting docker version string to chart version string"
    chartver = dockerver.replaceAll("_", "+")
    echo "Chart version is ${chartver}"

    echo "Writing chart version to .chart_version"
    writeFile(file: ".chart_version", text: chartver)

    ///////////////////
    // RPM version and release
    ///////////////////
    // RPM versions cannot contain the - character. If our version string contains a -, then we split the string.
    // The first part becomes the RPM version, the second part becomes the RPM release. The RPM release is also
    // not permitted to contain a - character, but a valid SemVer 2.0 version can at most contain one -, so this should
    // not be an issue.
    // If the version does not contain a -, then the entire version will be used for the RPM version, and the RPM release
    // will use the default value of 1.
    rpmrel = "1"
    if (ver.contains("-")) {
        echo "Version contains a dash. Splitting to create RPM version and release"
        ver_fields = ver.split("-")
        // Make sure there was just a single - character
        if (ver_fields.size() != 2) {
            error "Version contains unexpected number of dashes (should be exactly 0 or 1): ${ver}"
        }
        rpmver = ver_fields[0]
        rpmrel = ver_fields[1]
    } else {
        echo "Version does not contain a dash. Using default of 1 for RPM release"
        rpmver = ver
    }

    echo "RPM version is ${rpmver}"
    echo "Writing RPM version to .rpm_version"
    writeFile(file: ".rpm_version", text: rpmver)

    echo "RPM release is ${rpmrel}"
    echo "Writing RPM release to .rpm_release"
    writeFile(file: ".rpm_release", text: rpmrel)

    ///////////////////
    // Versions for other artifact types
    ///////////////////
    // The base version string is also what is used for Python modules, which is
    // why there are no .xxxx_version files generated for those
}

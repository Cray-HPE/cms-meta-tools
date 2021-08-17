// Copyright 2021 Hewlett Packard Enterprise Development LP
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// (MIT License)

def call() {
    def ver

    /// Need the CSM shared library for the getDockerBuildVersion function
    echo "Loading csm-shared-library, if it is not already loaded (an error message about this can be ignored)"
    library 'csm-shared-library'

    ///////////////////
    // Base version
    ///////////////////
    if fileExists('.version') {
        // Using static versioning
        echo ".version file exists -- using static versioning"
        echo "Reading base version from .version"
        ver = readFile('.version').trim()
        echo "Base version is ${ver}"    
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
    def dockerver = getDockerBuildVersion(isStable: env.IS_STABLE)
    echo "Docker version is ${dockerver}"

    echo "Writing docker version to .docker_version"
    writeFile(file: ".docker_version", text: dockerver)

    ///////////////////
    // Chart version
    ///////////////////
    echo "Converting docker version string to chart version string"
    def chartver = dockerver.replaceAll("_", "+")
    echo "Chart version is ${chartver}"

    echo "Writing chart version to .chart_version"
    writeFile(file: ".chart_version", text: chartver)

    ///////////////////
    // Versions for other artifact types
    ///////////////////
    // The base version string is also what is used for RPMs and Python modules, which is
    // why there are no .xxxx_version files generated for those
}

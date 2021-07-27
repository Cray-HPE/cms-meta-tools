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

// Possible parameters:
// baseName
// buildChart
// buildDocker
// buildRPM
// chartComponent
// dockerDescription
// dockerName
// rpmArch
// rpmComponent
// rpmName
// rpmSpecfile
// versionScript

def call(Map userConfig = [:]) {
    echo "cmtBuildPipeline"
    library 'csm-shared-library'

    if (!userConfig.containsKey("baseName")) {
        error "cmtBuildPipeline: baseName must be specified"
    }
    def baseName = config.baseName

    def defaults = [
        buildChart:         false,
        buildDocker:        false,
        buildRPM:           false,
        rpmArch:            "x86_64",
        versionScript:      ""
    ]
    def config = defaults + userConfig
    def chartComponent = ""
    def chartVersion = ""
    def dockerVersion = ""
    def dockerArgs = ""
    def dockerDescription = ""
    def dockerName = ""
    def rpmBuildMetadata = ""
    def rpmComponent = ""
    def rpmName = ""    
    def rpmSpecfile = ""
    def rpmArch = config.rpmArch

    // Convert buildChart, buildDocker, and buildRPM to Boolean values, if needed
    if (config.buildChart instanceof String) {
        config.buildChart = config.buildChart.toBoolean()
    } else if (!config.buildChart instanceof Boolean) {
        error "cmtBuildPipeline: buildChart argument must be boolean or string-equivalent"
    }
    if (config.buildDocker instanceof String) {
        config.buildDocker = config.buildDocker.toBoolean()
    } else if (!config.buildDocker instanceof Boolean) {
        error "cmtBuildPipeline: buildDocker argument must be boolean or string-equivalent"
    }
    if (config.buildRPM instanceof String) {
        config.buildRPM = config.buildRPM.toBoolean()
    } else if (!config.buildRPM instanceof Boolean) {
        error "cmtBuildPipeline: buildRPM argument must be boolean or string-equivalent"
    }

    // Verify that we have something to build
    if (!config.buildChart && !config.buildDocker && !config.buildRPM) {
        error "cmtBuildPipeline: buildChart, buildDocker, and buildRPM all false -- nothing to build!"
    }

    // Verify that we have necessary parameters and set some defaults
    if (config.buildChart) {
        if (config.containsKey("chartComponent") {
            chartComponent = config.chartComponent
        } else {
            chartComponent = config.baseName
        }
    }
    if (config.buildDocker) {
        if (!config.containsKey("dockerDescription") {
            error "cmtBuildPipeline: If building a docker image, dockerDescription must be specified"
        }
        dockerDescription = config.dockerDescription
        if (config.containsKey("dockerName") {
            dockerName = config.dockerName
        } else {
            dockerName = config.baseName
        }
    }
    if (config.buildRpm) {
        if (config.containsKey("rpmName") {
            rpmName = config.rpmName
        } else {
            rpmName = config.baseName
        }
        if (config.containsKey("rpmComponent") {
            rpmComponent = config.rpmComponent
        } else {
            rpmComponent = config.baseName
        }
        if (config.containsKey("rpmSpecfile") {
            rpmSpecfile = config.rpmSpecfile
        } else {
            rpmSpecfile = "${config.baseName}.spec"
        }
    }

    // Determine our base version, save it in baseVersion, write it to .version
    def baseVersion = cmtGetVersion(config.versionScript)

    // Determine whether this is a stable build or not
    isStable = getBuildIsStable()
    echo "cmtBuildPipeline: isStable = ${isStable}"

    if (config.buildDocker || config.buildChart) {
        // Get the docker version string, save it to dockerVersion, and write it to .docker_version
        // We do this even if we are building a chart and not a docker image, because the chart version
        // is just a modification of the docker version
        dockerVersion = cmtGetDockerVersion(baseVersion: baseVersion, isStable: isStable)

        if (config.buildDocker) {
            dockerArgs = getDockerBuildArgs(name: dockerName, description: dockerDescription, version: dockerVersion)
            echo "cmtBuildPipeline: dockerArgs = ${dockerArgs}"
        } else {
            echo "cmtBuildPipeline: Not building docker image"
        }

        // Get the chart version string, save it to chartVersion, and write it to .chart_version
        if (config.buildChart) {
            chartVersion = cmtGetChartVersion(dockerVersion)
        } else {
            echo "cmtBuildPipeline: Not building chart image"
        }
    }

    if (config.buildRPM) {
        rpmBuildMetadata = getRpmRevision(isStable: isStable)
        echo "cmtBuildPipeline: rpmBuildMetadata = ${rpmBuildMetadata}"
    } else {
        echo "cmtBuildPipeline: Not building RPM"
    }

    pipeline {
        agent {
            label "metal-gcp-builder"
        }

        options {
            buildDiscarder(logRotator(numToKeepStr: "10"))
            timestamps()
        }

        environment {
            NAME = baseName
            VERSION = baseVersion
            CHART_VERSION = chartVersion
            DOCKER_VERSION = dockerVersion
            DOCKER_ARGS = dockerArgs
            BUILD_METADATA = rpmBuildMetadata
        }
        
        stages {
            stage("Build Prep") {
                steps {
                    cmtRunBuildPrep()
                }
            }
            
            stage("Lint") {
                steps {
                    cmtRunLint()
                }
            }

            stage("RPM Add Metadata") {
                when { expression { return config.buildRPM } }
                steps {
                    runLibraryScript("addRpmMetaData.sh", rpmSpecfile)
                }
            }

            stage("RPM Prepare") {
                when { expression { return config.buildRPM } }
                steps {
                    sh "make rpm_prepare"
                }
            }
            
            stage("Build") {
                parallel {
                    stage("Chart") {
                        when { expression { return config.buildChart } }
                        steps {
                            sh "make chart"
                        }
                    }

                    stage('Docker Image') {
                        when { expression { return config.buildDocker } }
                        steps {
                            sh "make image"
                        }
                    }

                    stage('RPM') {
                        when { expression { return config.buildRPM } }
                        steps {
                            sh "make rptr_rpm"
                        }
                    }
                }
            }

            stage("Publish") {
                steps {
                    script {
                        if (config.buildDocker) {
                            publishCsmDockerImage(image: dockerName, tag: dockerVersion, isStable: isStable)
                        }
                        if (config.buildChart) {
                            publishCsmHelmCharts(component: chartComponent, chartsPath: "${WORKSPACE}/kubernetes/.packaged", isStable: isStable)
                        }
                        if (config.buildRPM) {
                            publishCsmRpms(component: rpmComponent, pattern: "dist/rpmbuild/RPMS/x86_64/*.rpm", arch: rpmArch, isStable: isStable)
                        }
                    }
                }
            }
        }
    }
}

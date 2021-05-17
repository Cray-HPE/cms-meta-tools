@Library('dst-shared@master') _

pipeline {

  agent { node { label 'dstbuild' } }

  environment {
    PRODUCT = 'csm'
    RELEASE_TAG = setReleaseTag()
  }

  stages {
    stage('Linting') {
      when {expression {return fileExists("runLint.sh") == true}}
      steps {
          sh "./runLint.sh"
      }
    }
    stage('Package') {
      steps {
        packageHelmCharts(chartsPath: "${env.WORKSPACE}/charts",
                          buildResultsPath: "${env.WORKSPACE}/build/results",
                          buildDate: "${env.BUILD_DATE}")
      }
    }
    stage('Publish') {
      steps {
        publishHelmCharts(chartsPath: "${env.WORKSPACE}/charts")
      }
    }
  }
  post {
    success {
      findAndTransferArtifacts()
    }
  }
}

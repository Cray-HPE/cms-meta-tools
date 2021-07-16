@Library('dst-shared') _
// NOTE: If this Jenkinsfile is removed, the a Jenkinsfile.github file must be created
// to do the github push. See the cray-product-install-charts repo for an example.
rpmBuild(
    autoJira: false,
    specfile: "cms-meta-tools.spec",
    build_arch: "noarch",
    buildArch: "noarch",
    product: "internal",
    fanout_params: ["sle15sp2"],
    buildPrepScript: "scripts/runBuildPrep.sh",
    lintScript: "scripts/runLint.sh",
    githubPushRepo: "Cray-HPE/cms-meta-tools",
    githubPushBranches: /(bugfix\/.*|feature\/.*|hotfix\/.*|master|release\/.*)/
)

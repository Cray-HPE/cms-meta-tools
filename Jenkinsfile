@Library('dst-shared') _
rpmBuild(
    autoJira: false,
    specfile: "cms-meta-tools.spec",
    build_arch: "noarch",
    buildArch: "noarch",
    product: "internal",
    fanout_params: ["sle15sp2"],
    buildPrepScript: "scripts/runBuildPrep.sh",
    lintScript: "scripts/runLint.sh",
)

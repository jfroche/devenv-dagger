{ pkgs
, ...
}:

{

  packages = [
    pkgs.git
  ];

  # https://devenv.sh/tests/
  enterTest = ''
    timeout 30 bash -c 'until pmexists; do sleep 1; done'
    echo "Running tests"
    # run a simple dagger task as a test
    dagger -c ".echo hello" | grep hello
    echo "check pmexists"
    pmexists
    echo "stop dagger-engine"
    devenv processes stop dagger-engine
    echo "check pmup"
    ! pmup
    echo "check pmdown"
    pmdown
    echo "check pmexists"
    ! pmexists
    echo "check pmdown"
    ! pmdown
    echo "check pmup"
    pmup
    pmexists
    pmdown
  '';

  services.dagger.enable = true;
  services.dagger.containerName = "dagger";
  services.podman-machine.machineName = "selinux";

  # https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    shellcheck.enable = true;
    nixpkgs-fmt.enable = true;
    actionlint.enable = true;
  };
}

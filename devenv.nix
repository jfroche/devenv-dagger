{ pkgs
, ...
}:

{

  packages = [
    pkgs.git
    pkgs.jq
  ];

  # https://devenv.sh/tests/
  enterTest = ''
    wait_for_processes
    dagger -c ".echo hello" | grep hello
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

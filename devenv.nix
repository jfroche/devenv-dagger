{ pkgs
, ...
}:

{
  imports = [
    ./podman.devenv.nix
    ./dagger.devenv.nix
  ];


  packages = [
    pkgs.git
  ];

  # https://devenv.sh/tests/
  enterTest = ''
    echo ""
    echo "Waiting for processes to be ready"
    PC_TUI_ENABLED=0 process-compose project is-ready --wait
    echo ""
    echo "Running tests"
    # run a simple dagger task as a test
    dagger -c ".echo hello" | grep hello
  '';

  services.dagger.enable = true;

  # https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    shellcheck.enable = true;
    nixpkgs-fmt.enable = true;
    actionlint.enable = true;
  };
}

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
    echo "Waiting for processes to be ready"
    devenv up -d
    process-compose project is-ready --wait
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

{ ...
}:

{
  imports = [
    ./podman.devenv.nix
    ./dagger.devenv.nix
  ];

  # https://devenv.sh/tests/
  enterTest = ''
    devenv processes down
    echo "Running tests"
    devenv up --detach
    # run a simple dagger task as a test
    dagger -c ".echo hello" | grep hello
    devenv processes down
  '';

  # https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    shellcheck.enable = true;
    nixpkgs-fmt.enable = true;
  };
}

{ inputs, ... }:
{
  imports = [
    "${inputs.upstream-devenv}/top-level.nix"
    ./dagger.nix
    ./podman.nix
  ];

  config = {
  };
}

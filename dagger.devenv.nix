{ config, pkgs, lib, ... }:
let
  dagger-nix = config.lib.getInput {
    name = "dagger-nix";
    url = "github:dagger/nix";
    attribute = "processes.dagger-engine-init";
    follows = ["nixpkgs"];
  };
in
{
  config = {
    env = {
      _EXPERIMENTAL_DAGGER_RUNNER_HOST="container+podman://dagger";
    };
    packages = [
      dagger-nix.packages.${pkgs.stdenv.hostPlatform.system}.dagger
    ];
    processes.dagger-engine-init = {
      exec = ''
        echo "Initializing dagger engine with Podman"
        export CONTAINER_CONNECTION="devenv-podman-machine"
        ${lib.getExe pkgs.podman} run --privileged --name dagger -p 6080:6080 registry.dagger.io/engine:v0.19.7
      '';
      process-compose = {
        depends_on = {
          podman-machine-start.condition = "process_completed_successfully";
        };
      };
    };
  };
}

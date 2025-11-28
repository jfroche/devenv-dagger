{ config
, pkgs
, lib
, ...
}:
let
  dagger-nix = config.lib.getInput {
    name = "dagger-nix";
    url = "github:dagger/nix";
    attribute = "processes.dagger-engine-init";
    follows = [ "nixpkgs" ];
  };
in
{
  config = {
    env = {
      _EXPERIMENTAL_DAGGER_RUNNER_HOST = "container+podman://dagger";
    };
    packages = [
      dagger-nix.packages.${pkgs.stdenv.hostPlatform.system}.dagger
    ];
    processes.dagger-engine = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "dagger-engine-init";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ];
          text = ''
            echo "Initializing dagger engine with Podman"
            export CONTAINER_CONNECTION="devenv-podman-machine"
            if podman ps --format json | jq '.[] | select( .Names[] == "dagger" and .State == "running" )' -e -r; then
              exit 0
            fi
            if podman ps -a --format json | jq '.[] | select( .Names[] == "dagger" )' -e -r; then
              echo "Starting existing dagger container..."
              podman start dagger
              exit 0
            fi
            podman run --privileged -d --name dagger -p 6080:6080 registry.dagger.io/engine:v0.19.7
          '';
        }
      );
      process-compose = {
        depends_on = {
          podman-machine-start.condition = "process_completed_successfully";
        };
      };
    };
  };
}

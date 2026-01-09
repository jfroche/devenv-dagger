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
            export CONTAINER_CONNECTION="${config.services.podman-machine.machineName}"
            if podman ps --format json | jq '.[] | select( .Names[] == "dagger" and .State == "running" )' -e -r > /dev/null; then
              echo "A container named 'dagger' is already running."
              echo ""
              exit 0
            fi
            if podman ps -a --format json | jq '.[] | select( .Names[] == "dagger" )' -e -r; then
              echo "Starting container named 'dagger'..."
              exec podman start -a dagger
            fi
            echo "Starting dagger engine with podman..."
            exec podman run --privileged --name dagger -p 6080:6080 registry.dagger.io/engine:v0.19.7
          '';
        }
      );
      process-compose = {
        depends_on = {
          podman-machine-start.condition = "process_healthy";
        };
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-dagger-ready" ''
              dagger -s -c ".echo hello"
            '';
          };
          period_seconds = 10;
          timeout_seconds = 2;
        };
      };
    };
  };
}

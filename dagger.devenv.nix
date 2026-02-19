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
  cfg = config.services.dagger;
  types = lib.types;
in
{
  options.services.dagger = {
    enable = lib.mkEnableOption "Dagger engine";

    containerName = lib.mkOption {
      default = "devenv-dagger";
      type = types.str;
      description = "Name of the container to start.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.podman-machine.enable = true;
    env = {
      _EXPERIMENTAL_DAGGER_RUNNER_HOST = "container+podman://${cfg.containerName}";
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
            pkgs.gawk
            dagger-nix.packages.${pkgs.stdenv.hostPlatform.system}.dagger
          ];
          text = ''
            export CONTAINER_CONNECTION="${config.services.podman-machine.machineName}"
            if podman ps --format json | jq '.[] | select( .Names[] == "${cfg.containerName}" and .State == "running" )' -e -r > /dev/null; then
              echo "A container named '${cfg.containerName}' is already running."
              echo ""
              exit 0
            fi
            if podman ps -a --format json | jq '.[] | select( .Names[] == "${cfg.containerName}" )' -e -r; then
              echo "Starting container named '${cfg.containerName}'..."
              exec podman start -a ${cfg.containerName}
            fi
            echo "Starting dagger engine with podman..."
            dagger_version=$(dagger version | awk '{print $2}')
            exec podman run --privileged --name ${cfg.containerName} -p 6080:6080 registry.dagger.io/engine:"''${dagger_version}"
          '';
        }
      );
      process-compose = {
        depends_on = {
          podman-machine.condition = "process_healthy";
        };
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-dagger-ready" ''
              dagger -s -c ".echo hello"
            '';
          };
          period_seconds = 10;
          initial_delay_seconds = 60;
          failure_threshold = 20;
          timeout_seconds = 30;
        };
        shutdown = {
          command = "podman stop ${cfg.containerName}";
          timeout_seconds = 10;
          signal = 9;
        };
      };
    };
  };
}

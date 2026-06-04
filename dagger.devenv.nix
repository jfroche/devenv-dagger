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

    scripts."dagger-pull-engine" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "dagger-pull-engine";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
            pkgs.gawk
            dagger-nix.packages.${pkgs.stdenv.hostPlatform.system}.dagger
          ];
          text = ''
            echo "Checking if podman machine is running."
            if podman machine list --format json | jq 'any(.[] | (.Name == "${config.services.podman-machine.machineName}" and .Running != true); .)' -e -r > /dev/null; then
              echo "Podman machine ${config.services.podman-machine.machineName} is not started."
              exit 0
            fi
            echo "Checking if dagger engine image has been pulled."
            dagger_version=$(dagger version | awk '{print $2}')
            image_name="registry.dagger.io/engine:''${dagger_version}"
            if podman image exists "''${image_name}"; then
              echo "Podman image ''${image_name} already pulled."
              echo ""
              exit 0
            fi
            echo "Pull podman image ''${image_name}..."
            podman image pull "''${image_name}"
          '';
        }
      );
    };

    tasks."dagger:pull-engine" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "dagger-pull-engine";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
            pkgs.gawk
            dagger-nix.packages.${pkgs.stdenv.hostPlatform.system}.dagger
          ];
          text = ''
            dagger-pull-engine
          '';
        }
      );
      before = [
        "devenv:enterShell"
        "devenv:enterTest"
      ];
      after = [
        "podman-machine:init"
      ];
    };
    scripts.dagger-ready-probe.exec = ''
      dagger core -s version > /dev/null 2>&1
    '';
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
            if podman ps --format json | jq '.[] | select( .Names[] == "${cfg.containerName}" and .State == "running" )' -e -r > /dev/null; then
              echo "A container named '${cfg.containerName}' is already running."
              echo ""
            elif podman ps -a --format json | jq '.[] | select( .Names[] == "${cfg.containerName}" )' -e -r; then
              echo "Starting existing container named '${cfg.containerName}'..."
              exec podman start -a ${cfg.containerName}
            else
              if ! podman volume exists dagger-cache; then
                echo "Creating dagger-cache volume"
                podman volume create dagger-cache
              fi
              dagger-pull-engine
              echo "Starting dagger engine with podman..."
              dagger_version=$(dagger version | awk '{print $2}')
              podman run --privileged --name ${cfg.containerName} -p 6080:6080 -v dagger-cache:/var/lib/dagger registry.dagger.io/engine:"''${dagger_version}"
            fi
          '';
        }
      );
      after = [ "devenv:processes:podman-machine@ready" ];
      ready = {
        exec = "dagger-ready-probe";
        initial_delay = 3;
        period = 3;
        probe_timeout = 2;
        failure_threshold = 6;
      };
    };
  };
}

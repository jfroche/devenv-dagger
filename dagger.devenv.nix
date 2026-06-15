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
  engineToml = pkgs.writeText "engine.toml" ''
    [registry."docker.io"]
    mirrors = ["mirror.gcr.io"]
  '';
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

    scripts."dagger-engine-init" = {
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
            containerName="${cfg.containerName}"
            if ! podman container exists "$containerName"; then
              if ! podman volume exists dagger-cache; then
                echo "Creating dagger-cache volume"
                podman volume create dagger-cache
              fi
              dagger-pull-engine
              echo "Starting dagger engine with podman..."
              daggerVersion=$(dagger version | awk '{print $2}')
              podman machine ssh ${config.services.podman-machine.machineName} -- \
                 'mkdir -p /etc/dagger && test -f /etc/dagger/engine.toml || cat > /etc/dagger/engine.toml' < ${engineToml}
              podman run --privileged --security-opt label=disable --name ${cfg.containerName} -p 6080:6080 \
                 -v dagger-cache:/var/lib/dagger \
                 -v /etc/dagger/engine.toml:/etc/dagger/engine.toml:ro \
                 registry.dagger.io/engine:"''${daggerVersion}"
            else
              currentImage=$(podman container inspect "$containerName" | jq '.[0].ImageName' | tr -d '"')
              daggerVersion=$(dagger version | awk '{print $2}')
              if [[ "$currentImage" == *"$daggerVersion" ]]; then
                if [ "$(podman inspect --format '{{.State.Running}}' $containerName 2>/dev/null)" = "true" ]; then
                  echo "Dagger engine is already running."
                else
                  echo "Starting existing container named '$containerName'."
                  exec podman start -a "$containerName"
                fi
              else
                echo "The existing container '$containerName' is built from '$currentImage'."
                echo "It might not be compatible with dagger version '$daggerVersion'."
                echo "Please make a decision like renaming it :"
                echo "$ podman rename $containerName myOtherName"
                exit 1
              fi
            fi
          '';
        }
      );
    };

    tasks."dagger:pull-engine" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "dagger-pull-engine-task";
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
      exec = "dagger-engine-init";
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

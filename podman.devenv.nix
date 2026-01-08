{ pkgs, lib, config, ... }:
let
  podman-machine-name = "devenv-podman-machine";
  cfg = config.services.podman-machine;
  types = lib.types;
in
{
  options.services.podman-machine = {
    enable = lib.mkEnableOption "Podman Machine";

    machineName = lib.mkOption {
      default = podman-machine-name;
      type = types.str;
      description = "Name of the machine to start.";
    };
  };

  config = lib.mkIf cfg.enable {
    env = {
      CONTAINER_CONNECTION = "${cfg.machineName}";
    };
    packages = [
      pkgs.podman
      pkgs.qemu
    ]
    ++ (lib.optionals pkgs.stdenv.isLinux [
      pkgs.virtiofsd
    ])
    ++ (lib.optionals pkgs.stdenv.isDarwin [
      pkgs.vfkit
    ]);

    processes.podman-machine-init = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "podman-machine-init";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ];
          text = ''
            if podman machine list --format json | jq 'any(.[] | (.Name == "${cfg.machineName}"); .)' -e -r > /dev/null; then
              echo "Podman machine '${cfg.machineName}' already exists."
              echo ""
              exit 0
            fi
            echo "Creating podman machine '${cfg.machineName}'..."
            echo ""
            podman --log-level debug machine init --rootful ${cfg.machineName}
          '';
        }
      );
    };
    processes.podman-machine-start = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "podman-machine-start";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
            pkgs.vfkit
          ];
          text = ''
            if podman machine list --format json | jq 'any(.[] | (.Name == "${cfg.machineName}" and .Running == true); .)' -e -r > /dev/null; then
              echo "Podman machine '${cfg.machineName}' is running."
              echo ""
              exit 0
            fi
            echo "Starting podman machine '${cfg.machineName}'..."
            echo ""
            podman --log-level debug machine start ${cfg.machineName}
          '';
        }
      );
      process-compose = {
        depends_on = {
          podman-machine-init.condition = "process_completed_successfully";
        };
      };
    };
  };
}

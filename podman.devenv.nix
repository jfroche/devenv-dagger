{ pkgs, lib, ... }:
let
  podman-machine-name = "devenv-podman-machine";
in
{
  config = {
    env = {
      CONTAINER_CONNECTION = "${podman-machine-name}";
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
            if podman machine list --format json | jq 'any(.[] | (.Name == "${podman-machine-name}"); .)' -e -r > /dev/null; then
              echo "Podman machine '${podman-machine-name}' already exists."
              echo ""
              exit 0
            fi
            echo "Creating podman machine '${podman-machine-name}'..."
            echo ""
            podman --log-level debug machine init --rootful ${podman-machine-name}
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
            if podman machine list --format json | jq 'any(.[] | (.Name == "${podman-machine-name}" and .Running == true); .)' -e -r > /dev/null; then
              echo "Podman machine '${podman-machine-name}' is running."
              echo ""
              exit 0
            fi
            echo "Starting podman machine '${podman-machine-name}'..."
            echo ""
            podman --log-level debug machine start ${podman-machine-name}
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

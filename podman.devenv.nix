{ pkgs, lib, ... }:
{
  config = {
    env = {
      CONTAINER_CONNECTION = "devenv-podman-machine";
    };
    packages = [
      pkgs.podman
      pkgs.qemu
    ]
    ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [
      pkgs.virtiofsd
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
            if podman machine list --format json | jq '.[] | (.Name == "devenv-podman-machine")' -e -r; then
              exit 0
            fi
            podman machine init --rootful devenv-podman-machine
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
          ];
          text = ''
            if podman machine list --format json | jq '.[] | (.Name == "devenv-podman-machine" and .Running == true)' -e -r; then
              exit 0
            fi
            echo "Starting Podman machine 'devenv-podman-machine'..."
            podman machine start devenv-podman-machine
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

{ pkgs, lib, ... }:
{
  config = {
    env = {
      CONTAINER_CONNECTION = "devenv-podman-machine";
    };
    packages = [
      pkgs.podman
      pkgs.qemu
      pkgs.virtiofsd
    ];
    processes.podman-machine-init = {
      exec = ''
        if podman machine list --format json | jq '.[] | (.Name == "devenv-podman-machine")' -e -r; then
          exit 0
        fi
        ${lib.getExe pkgs.podman} machine init --rootful devenv-podman-machine
      '';
    };
    processes.podman-machine-start = {
      exec = ''
        if podman machine list --format json | jq '.[] | (.Name == "devenv-podman-machine" and .Running == true)' -e -r; then
          exit 0
        fi
        echo "Starting Podman machine 'devenv-podman-machine'..."
        ${lib.getExe pkgs.podman} machine start devenv-podman-machine
      '';
      process-compose = {
        depends_on = {
          podman-machine-init.condition = "process_completed_successfully";
        };
      };
    };
  };
}

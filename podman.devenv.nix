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
        echo "Initializing Podman machine 'devenv-podman-machine'..."
        ${lib.getExe pkgs.podman} machine init --rootful devenv-podman-machine
      '';
    };
    processes.podman-machine-start = {
      exec = ''
        echo "Starting Podman machine 'devenv-podman-machine'..."
        ${lib.getExe pkgs.podman} machine start devenv-podman-machine
      '';
      process-compose = {
        depends_on = {
          podman-machine-init.condition = "process_completed_successfully";
        };
      };
      #before = [ "devenv:enterShell" ];
      # Start before entering the shell
      #before = [ "devenv:enterShell" ];
    };
  };
}

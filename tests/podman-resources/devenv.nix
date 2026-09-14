{ ... }:
{
  services.podman-machine.enable = true;
  services.podman-machine.machineName = "devenv-resources";
  services.podman-machine.memoryMiB = 3072;
  services.podman-machine.cpus = 2;
}

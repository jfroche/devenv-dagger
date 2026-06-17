{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.podman-machine;
  types = lib.types;
  podmanHelpersConf = pkgs.writeText "containers-override.conf" ''
    [engine]
    helper_binaries_dir = ["${pkgs.gvproxy}/bin", "${pkgs.qemu}/bin"]
  '';
in
{
  options.services.podman-machine = {
    enable = lib.mkEnableOption "Podman Machine";

    machineName = lib.mkOption {
      default = "devenv";
      type = types.str;
      description = "Name of the machine to start.";
    };
  };

  config = lib.mkIf cfg.enable {
    env = {
      CONTAINER_CONNECTION = "${cfg.machineName}";
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      CONTAINERS_CONF_OVERRIDE = "${podmanHelpersConf}";
    };
    packages = [
      pkgs.podman
      pkgs.qemu
    ]
    ++ (lib.optionals pkgs.stdenv.isLinux [
      pkgs.virtiofsd
      pkgs.gvproxy
    ])
    ++ (lib.optionals pkgs.stdenv.isDarwin [
      pkgs.vfkit
    ]);

    tasks."podman-machine:init" = {
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
            podman machine init --rootful ${cfg.machineName}
            # disable selinux
            # TODO move to specific task for dagger
            podman machine start ${cfg.machineName}
            podman machine ssh ${cfg.machineName} sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux 
            podman machine stop ${cfg.machineName}
            podman machine start ${cfg.machineName}
            podman machine ssh ${cfg.machineName} sestatus | grep disabled
            podman machine stop ${cfg.machineName}
          '';
        }
      );
      before = [
        "devenv:enterShell"
        "devenv:enterTest"
      ];
    };

    scripts."pmdown" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "pmdown";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ];
          text = ''
            if podman machine list --format json | jq 'any(.[] | (.Name == "${cfg.machineName}" and .Running == true); .)' -e -r > /dev/null; then
              podman machine stop ${cfg.machineName}
            else
              echo "Podman machine ${cfg.machineName} is already down."
              exit 1
            fi
          '';
        }
      );
    };

    scripts."pmup" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "pmup";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ];
          text = ''
            if podman machine list --format json | jq 'any(.[] | (.Name == "${cfg.machineName}" and .Running != true); .)' -e -r > /dev/null; then
              podman machine start ${cfg.machineName}
            else
              echo "Podman machine ${cfg.machineName} is already up."
              exit 1
            fi
          '';
        }
      );
    };

    scripts."pmst" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "pmst";
          runtimeInputs = [
            pkgs.podman
            pkgs.ripgrep
          ];
          text = ''
            podman machine ls | rg --color=never "VM TYPE"
            podman machine ls | rg --color=never "${cfg.machineName}"
            echo ""
          '';
        }
      );
    };


    scripts."pmexists" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "pmexists";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ];
          text = ''
            if podman machine list --format json | jq 'any(.[] | (.Name == "${cfg.machineName}" and .Running == true); .)' -e -r > /dev/null; then
               echo "Podman machine '${cfg.machineName}' is running..."
               exit 0
            else
              exit 1
            fi
          '';
        }
      );
    };

    processes.podman-machine = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "podman-machine";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ]
          ++ (lib.optionals pkgs.stdenv.isDarwin [
            pkgs.vfkit
          ]);

          text = ''
            trap 'exit 130' INT
            trap 'exit 143' TERM
            if pmexists; then
              echo "and will not be stopped."
            else
              cleanup() {
                pmdown
                exit 0
              }
              trap cleanup EXIT

              pmup
            fi
            sleep infinity &
            wait $!
          '';
        }
      );
      ready = {
        exec = "CONTAINER_CONNECTION=${cfg.machineName} podman ps";
        initial_delay = 1;
        period = 3;
        probe_timeout = 2;
        failure_threshold = 6;
      };
    };
  };
}

{ ... }:

{
  # Entry point when this flake is imported via `imports: - devenv-dagger`
  # in a consumer's devenv.yaml.
  imports = [ ./top-level.nix ];
}

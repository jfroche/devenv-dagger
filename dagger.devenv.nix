{ ... }:
{
  # Kept for consumers importing this file directly (flake:false input).
  # New consumers import the modules via ?dir=src/modules; see README.md.
  imports = [ ./src/modules/dagger.nix ];
}

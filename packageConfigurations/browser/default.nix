{
  pkgs,
  outputs,
  ...
}: let
  inherit (import ../../variables.nix) browser;
in {
  imports = [
    ./firefox/firefox.nix
    ./floorp/floorp.nix
  ];
}

{
  lib,
  pkgs,
  outputs,
  ...
}: {
  nixpkgs = {
    overlays =
      [
      ]
      ++ (builtins.attrValues outputs.overlays);
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
      ];
    };
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
    };
  };
}

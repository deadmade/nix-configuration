{outputs, ...}: {
  nixpkgs = {
    overlays = [
      outputs.overlays.unstable-packages
      outputs.overlays.modifications
    ];
    config.allowUnfree = true;
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];
}

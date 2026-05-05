{outputs, ...}: {
  imports = [
    outputs.nixosModules.gaming.steam
    outputs.nixosModules.gaming.gamescope
  ];
}

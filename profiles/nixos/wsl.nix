{outputs, ...}: {
  imports = [
    outputs.nixosModules.core.packages
    outputs.nixosModules.core.user
    outputs.nixosModules.core.localization
    outputs.nixosModules.core.optimize
    outputs.nixosModules.desktop.ai
  ];
}

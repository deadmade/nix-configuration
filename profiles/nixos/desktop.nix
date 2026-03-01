{outputs, ...}: {
  imports = [
    outputs.nixosProfiles.core
    outputs.nixosProfiles.virtualization
    outputs.nixosModules.desktop.base
    outputs.nixosModules.desktop.packages
    outputs.nixosModules.desktop.stylix
    outputs.nixosModules.desktop.vpn
    outputs.nixosModules.desktop.ai
    outputs.nixosModules.desktop.jetbrains
    outputs.nixosModules.desktop.bluetooth
  ];
}

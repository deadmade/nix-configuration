{outputs, ...}: {
  imports = [
    outputs.nixosModules.virtualization.container
    outputs.nixosModules.virtualization.vm
  ];
}

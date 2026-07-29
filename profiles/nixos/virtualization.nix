{outputs, ...}: {
  imports = [
    outputs.nixosModules.virtualization.docker
    outputs.nixosModules.virtualization.vm
  ];
}

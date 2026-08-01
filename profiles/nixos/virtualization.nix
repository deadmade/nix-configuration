{outputs, ...}: {
  imports = [
    outputs.nixosModules.virtualization.podman
    outputs.nixosModules.virtualization.vm
  ];
}

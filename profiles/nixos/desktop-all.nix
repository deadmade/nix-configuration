{outputs, ...}: {
  imports =
    [
      outputs.nixosProfiles.core
      outputs.nixosProfiles.virtualization
    ]
    ++ (builtins.attrValues outputs.nixosModules.desktop);
}

{outputs, ...}: {
  imports =
    [
      outputs.homeManagerModules.coding.direnv
      outputs.homeManagerModules.core.aliases
      outputs.homeManagerModules.core.homeConfig
      outputs.homeManagerModules.core.nixConfig
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.terminal);
}

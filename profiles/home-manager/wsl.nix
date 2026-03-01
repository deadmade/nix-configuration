{outputs, ...}: {
  imports =
    [
      outputs.homeManagerModules.coding.direnv
      outputs.homeManagerModules.core.aliases
      outputs.homeManagerModules.core.home
      outputs.homeManagerModules.core.nixConfig
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.terminal);
}

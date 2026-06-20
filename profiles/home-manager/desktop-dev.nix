{outputs, ...}: {
  imports =
    [
      outputs.homeManagerModules.hyprland
      outputs.homeManagerModules.browser.librewolf
      outputs.homeManagerModules.browser.helium
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core)
    ++ (builtins.attrValues outputs.homeManagerModules.terminal)
    ++ (builtins.attrValues outputs.homeManagerModules.coding);
}

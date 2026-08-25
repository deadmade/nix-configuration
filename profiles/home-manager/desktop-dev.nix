{outputs, ...}: {
  imports =
    [
      outputs.homeManagerModules.windowManager.hyprland
      outputs.homeManagerModules.browser.librewolf
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core)
    ++ (builtins.attrValues outputs.homeManagerModules.terminal)
    ++ (builtins.attrValues outputs.homeManagerModules.coding);
}

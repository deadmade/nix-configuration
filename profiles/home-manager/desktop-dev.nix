{outputs, ...}: {
  imports =
    [
      outputs.homeManagerModules.windowManager.hyprland
      outputs.homeManagerModules.browser.librewolf
      outputs.homeManagerModules.desktop.gtk
      outputs.homeManagerModules.desktop.qt
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core)
    ++ (builtins.attrValues outputs.homeManagerModules.terminal)
    ++ (builtins.attrValues outputs.homeManagerModules.coding);
}

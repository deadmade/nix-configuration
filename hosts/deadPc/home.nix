{
  outputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    outputs.homeManagerModules.windowManager.hyprland
    outputs.homeManagerModules.browser.librewolf
    outputs.homeManagerModules.desktop.gtk
    outputs.homeManagerModules.desktop.qt

    outputs.homeManagerModules.core.aliases
    outputs.homeManagerModules.core.btop
    outputs.homeManagerModules.core.git
    outputs.homeManagerModules.core.homeConfig
    outputs.homeManagerModules.core.nixConfig
    outputs.homeManagerModules.core.stylix

    outputs.homeManagerModules.terminal.fastfetch
    outputs.homeManagerModules.terminal.ghostty
    outputs.homeManagerModules.terminal.kitty
    outputs.homeManagerModules.terminal.nix-index
    outputs.homeManagerModules.terminal.starship
    outputs.homeManagerModules.terminal.tmux
    outputs.homeManagerModules.terminal.yazi
    outputs.homeManagerModules.terminal.zsh

    outputs.homeManagerModules.coding.direnv
    outputs.homeManagerModules.coding.vscodium
    outputs.homeManagerModules.coding.zed
  ];

  home.packages = with pkgs; [
    pkgs.helium
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        {
          output = "HDMI-A-1";
          mode = "1920x1080@60";
          position = "3840x0";
          scale = 1;
        }
        {
          output = "DP-2";
          mode = "1920x1080@60";
          position = "0x0";
          scale = 1;
        }
        {
          output = "DP-3";
          mode = "1920x1080@240";
          position = "1920x0";
          scale = 1;
        }
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
          mirror = "DP-3";
        }
      ];
    };
  };

  home.shellAliases = {
  };
}

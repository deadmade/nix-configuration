{
  outputs,
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
    pkgs.unstable.p3x-onenote
    teams-for-linux
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        {
          output = "eDP-1";
          mode = "1920x1200@60";
          position = "0x0";
          scale = 1;
        }
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
          mirror = "eDP-1";
        }
      ];
    };

    extraConfig = ''
      -- 14. Laptop keys
      -- Its own numbered heading so these do not inherit whatever section
      -- happens to precede them once home-manager concatenates the two blocks;
      -- see the keybinding preamble in the shared hyprland module for why the
      -- `-- N. Title` form and the descriptions matter.
      --
      -- Routed through noctalia rather than brightnessctl directly, so the
      -- Noctalia OSD actually appears and the shell's brightness state stays
      -- in sync. The XF86 keys are bound in the shared module -- these are the
      -- Fn-row duplicates, labelled distinctly because the cheatsheet maps a
      -- description string to exactly one category.
      hl.bind("SUPER + F5", hl.dsp.exec_cmd("noctalia msg brightness-down"), { repeating = true, description = "Brightness down (F5)" })
      hl.bind("SUPER + F6", hl.dsp.exec_cmd("noctalia msg brightness-up"), { repeating = true, description = "Brightness up (F6)" })
    '';
  };

  programs.noctalia.settings.idle = {
    pre_action_fade_seconds = lib.mkForce 2.0;
    behavior = {
      lock.timeout = lib.mkForce 300.0;
      screen-off.timeout = lib.mkForce 360.0;
      lock-and-suspend = {
        enabled = lib.mkForce true;
        timeout = 900.0;
      };
    };
  };

  programs.noctalia.settings.plugin_settings."noctalia/mpvpaper" = {
    auto_pause = "max";
  };

  home.shellAliases = {
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadConvertible && home-manager switch --flake .#deadmade@deadConvertible";
  };
}

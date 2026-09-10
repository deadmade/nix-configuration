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
    # Lua config: hl.monitor() requires a table, not the legacy string form.
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

    # Lua config: hl.bind() takes (keys, dispatcher), so the legacy comma-string
    # bind form is expressed as raw Lua here (merged via types.lines).
    extraConfig = ''
      -- Routed through noctalia rather than brightnessctl directly, so the
      -- Noctalia OSD actually appears and the shell's brightness state stays
      -- in sync. The XF86 keys are bound in the shared module.
      hl.bind("SUPER + F5", hl.dsp.exec_cmd("noctalia msg brightness-down"), { repeating = true })
      hl.bind("SUPER + F6", hl.dsp.exec_cmd("noctalia msg brightness-up"), { repeating = true })
    '';
  };

  # Laptop idle posture: much tighter than the desktop, and it does suspend.
  # mkForce because these leaves are already defined in the shared noctalia
  # module -- without it, two definitions of the same leaf conflict.
  programs.noctalia.settings.idle = {
    pre_action_fade_seconds = lib.mkForce 2.0;
    behavior = {
      lock.timeout = lib.mkForce 300.0; # 5 min
      screen-off.timeout = lib.mkForce 360.0; # 6 min
      lock-and-suspend = {
        enabled = lib.mkForce true;
        timeout = 900.0; # 15 min
      };
    };
  };

  # Video wallpaper on battery. Different leaves from the shared module's
  # video_directory, so these merge rather than conflict -- no mkForce needed.
  programs.noctalia.settings.plugin_settings."noctalia/mpvpaper" = {
    # A maximised browser hides the wallpaper as completely as a fullscreen one
    # does, and decoding a loop nobody can see is pure battery.
    #
    # NO-OP AS OF TODAY, kept deliberately: the mode is passed as
    # `--auto-mode MAX`, which mpvpaper only gained after 1.8, and
    # mpvpaper_service.luau:186-187 falls back to plain `--auto-pause` on 1.8 --
    # which is what pkgs.mpvpaper currently is. Verified against the live
    # process, whose argv carries no --auto-mode. This starts working on its own
    # the moment nixpkgs ships a newer mpvpaper; nothing else has to change.
    auto_pause = "max";
    # NOT set: mpv_options = "--panscan=1.0". The plugin hardcodes panscan=1.0
    # into every launch (mpvpaper_service.luau:150), so the 1080p loops already
    # fill this 1200p panel by cropping rather than letterboxing.
  };

  home.shellAliases = {
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadConvertible && home-manager switch --flake .#deadmade@deadConvertible";
  };
}

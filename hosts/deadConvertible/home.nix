{
  outputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    outputs.homeManagerProfiles.desktopDev
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

  home.shellAliases = {
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadConvertible && home-manager switch --flake .#deadmade@deadConvertible";
  };
}

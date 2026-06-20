{
  outputs,
  pkgs,
  config,
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
      ];
    };

    # Lua config: hl.bind() takes (keys, dispatcher), so the legacy comma-string
    # bind form is expressed as raw Lua here (merged via types.lines).
    extraConfig = ''
      hl.bind("SUPER + F5", hl.dsp.exec_cmd("brightnessctl set 10%-"))
      hl.bind("SUPER + F6", hl.dsp.exec_cmd("brightnessctl set 10%+"))
    '';
  };

  services.wpaperd = {
    settings = {
      eDP-1 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
    };
  };

  home.shellAliases = {
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadConvertible && home-manager switch --flake .#deadmade@deadConvertible";
  };
}

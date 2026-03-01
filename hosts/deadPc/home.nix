{
  outputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    outputs.homeManagerProfiles.desktopGaming
  ];

  home.packages = with pkgs; [
    telegram-desktop
  ];

  nixpkgs = {
    overlays = [
      outputs.overlays.unstable-packages
      outputs.overlays.modifications
    ];
    config.allowUnfree = true;
  };

  wayland.windowManager.hyprland = {
    settings = {
      # Drei Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an)
      monitor = [
        "HDMI-A-1,1920x1080@60,3840x0,1" # Rechter Monitor
        "DP-2, 1920x1080@60,0x0,1" # Linker Monitor
        "DP-3, 1920x1080@240,1920x0,1" # Mittlerer Monitor
      ];
    };
  };

  services.wpaperd = {
    settings = {
      DP-3 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
      DP-2 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
      HDMI-A-1 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
    };
  };

  gtk = {
    enable = true;
  };

  home.shellAliases = {
  };
}

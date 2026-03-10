{
  outputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    outputs.homeManagerProfiles.desktopGaming
  ];

  home.packages = with pkgs; [
  ];

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

  programs.noctalia-shell.settings.bar.screenOverrides = lib.mkForce [
    {
      name = "DP-2";
      widgets = {
        left = [
          {
            id = "Launcher";
          }
          {
            id = "Clock";
          }
          {
            id = "SystemMonitor";
          }
          {
            id = "ActiveWindow";
          }
          {
            id = "MediaMini";
          }
        ];
        center = [
          {
            id = "Workspace";
          }
        ];
        right = [
          {
            id = "Tray";
          }
          {
            id = "NotificationHistory";
          }
          {
            id = "Battery";
          }
          {
            id = "Volume";
          }
          {
            id = "Brightness";
          }
          {
            id = "ControlCenter";
          }
        ];
      };
    }
    {
      name = "HDMI-A-1";
      widgets = {
        left = [
          {
            id = "Workspace";
          }
          {
            id = "plugin:news";
          }
          {
            id = "plugin:ip-monitor";
          }
        ];
        center = [
        ];
        right = [
          {
            id = "Tray";
            drawerEnabled = false; # Show all tray icons directly in bar
          }
          {
            id = "Volume";
          }
          {
            displayMode = "onhover";
            id = "WiFi";
          }
          {
            colorName = "error";
            id = "SessionMenu";
          }
          {
            id = "Clock";
          }
          {
            hideWhenZero = true;
            id = "NotificationHistory";
            showUnreadBadge = true;
          }
          {
            colorizeDistroLogo = false;
            colorizeSystemIcon = "primary";
            customIconPath = "";
            enableColorization = true;
            icon = "noctalia";
            id = "ControlCenter";
            useDistroLogo = true;
          }
        ];
      };
    }
  ];

  gtk = {
    enable = true;
  };

  home.shellAliases = {
  };
}

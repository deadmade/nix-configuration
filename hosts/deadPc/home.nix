{
  outputs,
  config,
  pkgs,
  ...
}: {
  imports =
    [
      outputs.homeManagerModules.hyprland
      outputs.homeManagerModules.browser.librewolf
      outputs.homeManagerModules.socialMedia.vencord
      #outputs.homeManagerModules.flatpak
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core)
    ++ (builtins.attrValues outputs.homeManagerModules.coding)
    ++ (builtins.attrValues outputs.homeManagerModules.terminal);

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
      # Drei Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an) -> umgedreht geht es. KP why
      monitor = [
        "DP-3, 1920x1080@60,0x0,1" # Linker Monitor
        "DP-2, 1920x1080@240,1920x0,1" # Mittlerer Monitor
        "HDMI-A-1,1920x1080@60,3840x0,1" # Rechter Monitor
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

  services.udiskie = {
    enable = true;
    settings = {
      # workaround for
      # https://github.com/nix-community/home-manager/issues/632
      program_options = {
        # replace with your favorite file manager
        file_manager = "${pkgs.nemo-with-extensions}/bin/nemo";
      };
    };
  };
}

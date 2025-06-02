{
  inputs,
  outputs,
  pkgs,
  username,
  host,
  config,
  ...
}: let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in {
  imports =
    [
      outputs.homeManagerModules.hyprland
      outputs.homeManagerModules.coding
      outputs.homeManagerModules.browser.librewolf
      outputs.homeManagerModules.terminal
      outputs.homeManagerModules.socialMedia.vencord
      outputs.homeManagerModules.flatpak
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core);

  home.packages = with pkgs; [
    remnote
    pkgs.unstable.texlive.combined.scheme-full
    pkgs.unstable.whatsapp-for-linux
    pkgs.unstable.p3x-onenote
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "eDP-1, 1920x1200@60,0x0,1"
      ];

      bind = [
        "$mainMod, F5,exec,brightnessctl set 10%-"
        "$mainMod, F6,exec,brightnessctl set 10%+"
      ];
    };
  };

  services.wpaperd = {
    settings = {
      eDP-1 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
    };
  };
}

{
  inputs,
  outputs,
  pkgs,
  username,
  host,
  ...
}: let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in
  {
  imports =
    [
      outputs.homeManagerModules.hyprland
      outputs.homeManagerModules.coding
      outputs.homeManagerModules.browser.librewolf
      outputs.homeManagerModules.terminal
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

      bind =[
        "$mainMod F5,exec,light -A 10"
        "mainMod F6,exec,light -U 10"
      ]
    };
  };
  }


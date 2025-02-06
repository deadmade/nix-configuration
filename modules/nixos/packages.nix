{ config, pkgs, ... }:
{
      environment.systemPackages = with pkgs; [
        neofetch
        htop
        curl       
        git
        floorp
        kitty
  ];

  # Enable hy
  programs.hyprland.enable = true; # enable Hyprland

}
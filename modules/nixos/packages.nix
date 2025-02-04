{ config, pkgs, ... }:
{
      environment.systemPackages = with pkgs; [
        neofetch
        gh
        htop
        curl       
  ];

}
{ config, pkgs, ... }:
{
      environment.systemPackages = with pkgs; [
        neofetch
        python3
        
  ];

}
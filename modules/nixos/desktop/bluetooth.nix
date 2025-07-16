{
  config,
  pkgs,
  inputs,
  outputs,
  ...
}: {
  hardware.bluetooth.enable = true;
  hardware.bluetooth = {
    settings = {
      General = {
        Experimental = true;
        Enable = "Source,Sink,Media,Socket";
      };
    };
    powerOnBoot = true; # powers up the default Bluetooth controller on boot
  };

  environment.systemPackages = with pkgs; [
    blueman
  ];

  #wiegurad setup
  # https://nixos.wiki/wiki/WireGuard
  # nmcli connection import type wireguard file thefile.conf
  # nmcli con up id NameOfTheConnection
}

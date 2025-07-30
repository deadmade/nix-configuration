{
  config,
  pkgs,
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  environment.systemPackages = with pkgs; [
    #pkgs.unstable.freetube
    pkgs.unstable.protonmail-desktop
    pkgs.unstable.kdePackages.okular
    #pkgs.unstable.spotify
    pkgs.unstable.spotify-player
    pkgs.unstable.libreoffice-fresh
    pkgs.unstable.thunderbird
    #pkgs.unstable.birdtray
    #pkgs.unstable.teamspeak6-client
    pkgs.unstable.opencode
  ];

  programs.thunar.enable = true;
  programs.xfconf.enable = true;

  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
  ];

  services.flatpak.enable = true;
  services.fwupd.enable = true;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/deadmade/nix-configuration";
  };

  programs.nano.enable = false;
  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images
}

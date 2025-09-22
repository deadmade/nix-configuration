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
    pkgs.unstable.protonmail-desktop
    pkgs.unstable.kdePackages.okular
    pkgs.unstable.spotify
    pkgs.unstable.spotify-player
    pkgs.unstable.libreoffice-fresh
    pkgs.unstable.thunderbird
    pkgs.unstable.opencode
    pkgs.unstable.remnote
    pkgs.nwg-displays
    pkgs.unstable.presenterm
    vlc
    home-manager
  ];

  services.xserver.excludePackages = with pkgs; [xterm];

  programs.xfconf.enable = true;

  services.flatpak.enable = true;
  services.fwupd.enable = false;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/deadmade/nix-configuration";
  };

  programs.nano.enable = true;
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;

  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = false; # Thumbnail support for images
}

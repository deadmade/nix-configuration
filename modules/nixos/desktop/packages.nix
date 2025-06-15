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
    pkgs.unstable.freetube
    pkgs.unstable.protonmail-desktop
    pkgs.unstable.kdePackages.okular
    pkgs.unstable.spotify
    pkgs.unstable.spotify-player
  ];

  # #TODO: Move this
  # programs.hyprland = {
  #   enable = true;
  #   xwayland.enable = true;
  # };

  programs.thunar.enable = true;
  programs.xfconf.enable = true;

  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
  ];

  services.flatpak.enable = true;

  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images
}

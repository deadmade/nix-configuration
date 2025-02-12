{
  config,
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    neofetch
    htop
    curl
    git
    floorp
    kitty
    ranger
    pkgs.unstable.freetube
    onlyoffice-desktopeditors
    pkgs.unstable.protonmail-desktop
    pkgs.unstable.protonvpn-gui
    vim
    #inputs.nvix.packages.${pkgs.system}.default
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.thunar.enable = true;
  programs.xfconf.enable = true;

  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
  ];

  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images

  services.flatpak.enable = true;

  virtualisation.docker.enable = true;
}

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
    neofetch
    curl
    git
    btop
    kitty
    ranger
    cachix
    #pkgs.unstable.vulnix
  ];

  home-manager.extraSpecialArgs = {inherit inputs outputs;};
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  #TODO: Move this
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.thunar = {
    enable = true;
  };

  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images

  services.flatpak.enable = true;

  virtualisation.docker.enable = true;
}

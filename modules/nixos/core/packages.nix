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
    curl
    git
    btop
    kitty
    #cachix
    #pkgs.unstable.vulnix
    #age
    wl-clipboard
  ];

  home-manager.extraSpecialArgs = {inherit inputs outputs;};
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  programs.thunar = {
    enable = true;
  };

  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images
}

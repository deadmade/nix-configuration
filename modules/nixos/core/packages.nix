{
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
    wl-clipboard
    superfile
    kitty
  ];

  programs.nix-ld.enable = true;

  home-manager.extraSpecialArgs = {inherit inputs outputs;};
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
}

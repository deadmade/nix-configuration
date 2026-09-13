{
  pkgs,
  inputs,
  outputs,
  vars,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    inputs.nixos-wsl.nixosModules.default
    outputs.nixosModules.core.defaults
    outputs.nixosModules.core.packages
    outputs.nixosModules.core.user
    outputs.nixosModules.core.localization
    outputs.nixosModules.core.optimize
    outputs.nixosModules.desktop.ai
  ];

  wsl.enable = true;
  wsl.defaultUser = vars.username;

  environment.systemPackages = with pkgs; [
    home-manager
  ];

  wsl.docker-desktop.enable = true;
  environment.variables.EDITOR = "nvim";

  system.stateVersion = "24.05";
}

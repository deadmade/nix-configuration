# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL
{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  vars,
  ...
}: {
  imports = [
    # include NixOS-WSL modules
    ./hardware-configuration.nix

    inputs.nixos-wsl.nixosModules.default
    outputs.nixosModules.core.packages
    outputs.nixosModules.core.user
    outputs.nixosModules.core.localization
    #outputs.nixosModules.core.network

    #outputs.nixosModules.funshit
  ];

  wsl.enable = true;
  wsl.defaultUser = vars.username;

  # Allow unfree packages
  nixpkgs = {
    overlays = [
      outputs.overlays.unstable-packages
    ];
    config.allowUnfree = true;
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  environment.systemPackages = with pkgs; [
    inputs.neovim-config.packages.${pkgs.system}.nvim
    nh
  ];

  environment.variables.EDITOR = "nvim";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}

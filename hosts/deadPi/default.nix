{
  pkgs,
  lib,
  inputs,
  outputs,
  ...
}: {
  imports = [
    #./hardware-configuration.nix

    #inputs.hardware.nixosModules.rasperry-pi-4
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base

    outputs.nixosModules.core.localization
  ];

  # systemPackages
  environment.systemPackages = with pkgs; [
    neovim
    curl
    wget
  ];

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  networking.firewall.enable = false;
  security.polkit.enable = true;

  # Networking
  networking.useDHCP = true;

  # put your own configuration here, for example ssh keys:
  users.mutableUsers = true;
  users.users.nixos = {
    isNormalUser = true;
    password = "changeme";
    extraGroups = ["wheel" "docker" "networkmanager"];
  };
  users.users.admin = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    hashedPassword = "blablabla"; # generate with `mkpasswd`
  };

  users.users.nixos.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINefXzpuLDcAive+X3n4YsrtF034oQAnAbL8Nc57stCg manuel.schuelein@proton.me"
  ];
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINefXzpuLDcAive+X3n4YsrtF034oQAnAbL8Nc57stCg manuel.schuelein@proton.me"
  ];

  nix.settings.trusted-users = ["admin" "deadmade" "nixos"];

  system.nixos.tags = let
    cfg = config.boot.loader.raspberryPi;
  in [
    "raspberry-pi-${cfg.variant}"
    cfg.bootloader
    config.boot.kernelPackages.kernel.version
  ];

  # allow nix-copy to live system
  nix.settings.trusted-users = ["nixos"];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # We are stateless, so just default to latest.
  system.stateVersion = config.system.nixos.release;
}

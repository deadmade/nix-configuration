{
  pkgs,
  lib,
  inputs,
  outputs,
  ...
}: {
  imports = [
      ./hardware-configuration.nix

    #inputs.hardware.nixosModules.rasperry-pi-4

    #outputs.nixosModules.core.localization
  ];
  #imports = [../common/global/locale.nix];
  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  # !!! Set to specific linux kernel version
  boot.kernelPackages = pkgs.linuxPackages;

  # Disable ZFS on kernel 6
  boot.supportedFilesystems = lib.mkForce [
    "vfat"
    "xfs"
    "cifs"
    "ntfs"
  ];

  # !!! Needed for the virtual console to work on the RPi 3, as the default of 16M doesn't seem to be enough.
  # If X.org behaves weirdly (I only saw the cursor) then try increasing this to 256M.
  # On a Raspberry Pi 4 with 4 GB, you should either disable this parameter or increase to at least 64M if you want the USB ports to work.
  #boot.kernelParams = ["cma=256M"];

  # !!! Adding a swap file is optional, but strongly recommended!
  swapDevices = [
    {
      device = "/swapfile";
      size = 1024;
    }
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

  services.restic.server = {
    enable = true;
    dataDir = "/mnt/backups";
    extraFlags = ["--no-auth"];
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  virtualisation.docker.enable = true;

  networking.firewall.enable = false;

  # Networking
  networking.useDHCP = true;

  # forwarding
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
    "net.ipv4.tcp_ecn" = true;
  };

  # put your own configuration here, for example ssh keys:
  users.mutableUsers = true;
  users.users.nixos = {
    isNormalUser = true;
    password = "changeme";
    extraGroups = ["wheel" "docker"];
  };
  users.users.admin = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    hashedPassword = "blablabla"; # generate with `mkpasswd`
  };
  nix.settings.trusted-users = ["admin" "deadmade" "nixos"];

  system.stateVersion = "25.05";
}

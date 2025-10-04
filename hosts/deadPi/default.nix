{
  pkgs,
  lib,
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.raspberry-pi-4

    outputs.nixosModules.core.localization
  ];

  # trim down initrd modules
  boot.supportedFilesystems = lib.mkForce ["vfat" "ext4"];
  boot.initrd = {
    includeDefaultModules = false;
    kernelModules = [
      "ext4"
      "mmc_block"

      # https://www.raspberrypi.com/documentation/computers/processors.html#bcm2835
      "bcm2835_dma"
      "i2c_bcm2835"
      "vc4" # Broadcom VideoCore 4 graphics driver
    ];
    availableKernelModules = lib.mkForce [
      "mmc_block"
      "usbhid"
      "hid_generic"
      "xhci_pci"
    ];
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  services.udisks2.enable = true;

  # systemPackages
  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    #mergerfs
  ];

  # fileSystems."/storage" = {
  #   fsType = "fuse.mergerfs";
  #   device = "/mnt/disks/*";
  #   options = ["cache.files=partial" "dropcacheonclose=true" "category.create=mfs"];
  # };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  services.restic.server = {
    enable = true;
    dataDir = "/storage";
    extraFlags = ["--no-auth"];
  };

  #services.tailscale = {
  #  enable = true;
  #  useRoutingFeatures = "server";
  #};

  # virtualisation.docker.enable = true;

  networking.firewall.enable = false;

  networking = {
    hostName = "deadpi";
    interfaces.end0 = {
      ipv4.addresses = [{
        address = "192.168.1.42";
        prefixLength = 24;
      }];
    };
    defaultGateway = {
      address = "192.168.1.1"; # or whichever IP your router is
      interface = "end0";
    };
    nameservers = [
      "192.168.1.1" # or whichever DNS server you want to use
    ];
    useDHCP = true;
  };

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
    hashedPassword = "$y$j9T$PLtMO97QQTuR0XDRy3SAz.$Wg2UvrJsJ4t0DcSTa1ATQgDI4G0PrYiWT3XFmUYtC1.";
    extraGroups = ["wheel" "docker"];
  };

  users.users.admin = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    hashedPassword = "$y$j9T$PLtMO97QQTuR0XDRy3SAz.$Wg2UvrJsJ4t0DcSTa1ATQgDI4G0PrYiWT3XFmUYtC1.";
  };

  nix.settings.trusted-users = ["admin" "deadmade" "nixos"];

  nixpkgs.hostPlatform = "aarch64-linux";
  #nixpkgs.buildPlatform = "x86_64-linux"; # needed ffs
  system.stateVersion = "25.05";
}

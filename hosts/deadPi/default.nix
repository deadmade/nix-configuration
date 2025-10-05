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
    outputs.nixosModules.core.optimisation
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

  services.udisks2.enable = false;

  # systemPackages
  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    mergerfs
  ];

  fileSystems."/mnt/disks/sda1" = {
    device = "/dev/disk/by-uuid/05fd1e96-119c-4481-a1b8-99c0952f066d";
    fsType = "xfs";
  };

  fileSystems."/mnt/disks/sdb1" = {
    device = "/dev/disk/by-uuid/014319f9-46d9-4941-b06b-8277ff4988a0";
    fsType = "xfs";
  };

  fileSystems."/mnt/disks/sdc1" = {
    device = "/dev/disk/by-uuid/846c7e5b-a1a0-4053-b753-f2ccbdd36f93";
    fsType = "xfs";
  };

  fileSystems."/storage" = {
    fsType = "fuse.mergerfs";
    device = "/mnt/disks/*";
    options = ["cache.files=partial" "dropcacheonclose=true" "category.create=mfs"];
    depends = [
      "/mnt/disks/sda1"
      "/mnt/disks/sdb1"
      "/mnt/disks/sdc1"
    ];
  };

  servies.sambe = {
    sambe = {
      enable = true;
    };
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
      ipv4.addresses = [
        {
          address = "192.168.1.42";
          prefixLength = 24;
        }
      ];
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
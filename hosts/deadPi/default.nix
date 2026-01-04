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
    outputs.nixosModules.core.optimize
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
    superfile
    git
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

  services = {
    samba = {
      package = pkgs.samba4Full;
      enable = false;
      openFirewall = true;

      shares.testshare = {
        path = "/storage";
        writable = "true";
        comment = "Hello World!";
      };
    };

    samba-wsdd = {
      enable = false;
      discovery = true;
      openFirewall = true;
    };

    avahi = {
      enable = false;
      openFirewall = true;

      publish.enable = true;
      publish.userServices = true;
      #nssmdns4 = true;
    };

    restic.server = {
      enable = true;
      listenAddress = "192.168.1.42:8000";
      dataDir = "/storage";
      extraFlags = ["--no-auth"];
    };
  };

  # virtualisation.docker.enable = true;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [8000];

  networking = {
    hostName = "deadpi";
    useDHCP = lib.mkForce true;
  };

  # forwarding
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
    "net.ipv4.tcp_ecn" = true;
  };

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
  #nixpkgs.buildPlatform = "x86_64-linux"; # needed for cross compiling the sd image
  system.stateVersion = "25.05";
}

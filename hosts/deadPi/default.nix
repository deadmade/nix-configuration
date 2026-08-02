{
  pkgs,
  lib,
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.raspberry-pi-4

    outputs.nixosModules.core.defaults
    outputs.nixosModules.core.localization
    outputs.nixosModules.core.optimize
  ];

  # Override nixos-hardware's Raspberry Pi kernel with a mainline one.
  #
  # nixos-hardware/raspberry-pi/common/kernel.nix pins a tag of the
  # raspberrypi/linux fork and builds it via nixpkgs' buildLinux. That only
  # substitutes when the pin happens to match a derivation Hydra built, and it
  # currently does not: linux-rpi-6.18.34-stable_20260609 returns 404 from
  # cache.nixos.org, so deploying meant compiling a kernel under qemu-aarch64
  # emulation on deadPc (abandoned after 1h20m on 24 cores).
  #
  # 6.12.97 is cached, and stays in the same 6.12 LTS series the Pi already
  # runs (6.12.47), so this is the smallest change that makes deploys tractable.
  # Verified against this host's requirements: dtbs/broadcom/bcm2711-rpi-4-b.dtb
  # is present, every module named below resolves, and pcie-brcmstb,
  # reset-raspberrypi and brcmfmac are all available.
  #
  # Tradeoff: loses Raspberry Pi Foundation patches — camera/unicam, hardware
  # video codecs, some device-tree overlays. None are used by this headless host.
  #
  # nixos-hardware sets kernelPackages with lib.mkDefault, so a plain assignment
  # is enough to override it.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

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

      settings = {
        testshare = {
          path = "/storage";
          "read only" = "no";
          comment = "Hello World!";
        };
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
      listenAddress = "10.10.10.137:8000";
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
    initialHashedPassword = lib.mkForce null;
    hashedPassword = "$y$j9T$PLtMO97QQTuR0XDRy3SAz.$Wg2UvrJsJ4t0DcSTa1ATQgDI4G0PrYiWT3XFmUYtC1.";
    extraGroups = ["wheel" "docker"];
  };

  users.users.admin = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBHA2a226b67E3wsCDfY7kgrZCCXju7E+4HNrfykglZ3 manuel.schuelein@proton.me"
    ];
    hashedPassword = "$y$j9T$PLtMO97QQTuR0XDRy3SAz.$Wg2UvrJsJ4t0DcSTa1ATQgDI4G0PrYiWT3XFmUYtC1.";
  };

  nix.settings.trusted-users = ["admin" "deadmade" "nixos"];

  nixpkgs.hostPlatform = "aarch64-linux";
  #nixpkgs.buildPlatform = "x86_64-linux"; # needed for cross compiling the sd image
  system.stateVersion = "25.05";
}

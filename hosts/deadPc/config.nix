{
  config,
  pkgs,
  outputs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./mainboard.nix

    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.hardware.nixosModules.common-pc-ssd

    outputs.nixosModules.core.defaults
    outputs.nixosModules.core.grub2-bootloader
    outputs.nixosModules.core.localization
    outputs.nixosModules.core.network
    outputs.nixosModules.core.nix-mineral
    outputs.nixosModules.core.nixsecauditor
    outputs.nixosModules.core.optimize
    outputs.nixosModules.core.packages
    outputs.nixosModules.core.security
    outputs.nixosModules.core.user

    outputs.nixosModules.desktop.ai
    outputs.nixosModules.desktop.base
    outputs.nixosModules.desktop.bluetooth
    outputs.nixosModules.desktop.jetbrains
    outputs.nixosModules.desktop.logitech
    outputs.nixosModules.desktop.packages
    outputs.nixosModules.desktop.stylix
    outputs.nixosModules.desktop.tailscale
    outputs.nixosModules.desktop.vpn
    outputs.nixosModules.desktop.wayvnc

    outputs.nixosModules.virtualization.podman
    outputs.nixosModules.virtualization.vm
    outputs.nixosModules.virtualization.vmware
  ];

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];

  nix.settings.extra-platforms = config.boot.binfmt.emulatedSystems;

  networking.hostName = "deadPc";

  services.xserver.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_7_2;

  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };
  services.printing = {
    enable = false;
    browsing = true;
    drivers = [pkgs.cnijfilter2 pkgs.canon-cups-ufr2];
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  users.users.deadmade = {
    isNormalUser = true;
    description = "deadmade";
    extraGroups = ["networkmanager" "wheel"];
  };

  services.displayManager.autoLogin.enable = false;
  services.displayManager.autoLogin.user = "deadmade";

  environment.systemPackages = with pkgs; [
    tuigreet
    inputs.neovim-config.packages.${pkgs.stdenv.hostPlatform.system}.nvim
    inputs.chiplang-nix.packages.${pkgs.stdenv.hostPlatform.system}.depthfinder
    inputs.chiplang-nix.packages.${pkgs.stdenv.hostPlatform.system}.dfn-mounter
    inputs.gitluxe.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.unstable.vlc
    pkgs.unstable.telegram-desktop
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "deadmade";
        command = "${pkgs.tuigreet}/bin/tuigreet
        --issue
        --theme border=magenta;text=cyan;prompt=green;time=red;action=blue;button=yellow;container=black;input=red
        --cmd Hyprland";
      };
    };
  };

  hardware = {
    graphics.enable = true;

    graphics.enable32Bit = true;
    nvidia = {
      open = false;
      powerManagement.enable = true;

      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "595.99.02";
        sha256_64bit = "sha256-6HR3lYv3YwcFSTJL1a1slI66btIQ5EAFs+/4SUD24ew=";
        sha256_aarch64 = "sha256-CCqHZTN2KNOZ4yZp2rDcuRJp9pHfRw47k4m4dWnS/2w=";
        openSha256 = "sha256-T36x/jx8yQ8l3LFp1rZIrTfcSwbGy8YSAvXOUSptpb4=";
        settingsSha256 = "sha256-GYCcnxfKPrTCrsmd25sMyzfC5cqJQJx0c31haooyTYM=";
        persistencedSha256 = "sha256-VyKtF/HdHPQrHHK6opSO69M72LmnGZtauuchj9uuje8=";
      };
    };
    logitech.wireless = {
      enable = true;
    };
  };

  system.stateVersion = "24.11";
}

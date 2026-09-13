{
  pkgs,
  outputs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-ssd

    outputs.nixosModules.core.defaults
    outputs.nixosModules.core.grub2-bootloader
    outputs.nixosModules.core.localization
    outputs.nixosModules.core.network
    outputs.nixosModules.core.nixsecauditor
    outputs.nixosModules.core.optimize
    outputs.nixosModules.core.packages
    outputs.nixosModules.core.security
    outputs.nixosModules.core.user

    outputs.nixosModules.desktop.base
    outputs.nixosModules.desktop.bluetooth
    outputs.nixosModules.desktop.packages
    outputs.nixosModules.desktop.stylix
    outputs.nixosModules.desktop.vpn
    outputs.nixosModules.desktop.ai
    outputs.nixosModules.desktop.jetbrains
    outputs.nixosModules.desktop.tailscale
    outputs.nixosModules.desktop.wayvnc

    outputs.nixosModules.virtualization.podman
    outputs.nixosModules.virtualization.vm
  ];

  networking.hostName = "deadConvertible";
  networking.networkmanager.enable = true;

  services.xserver.enable = false;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = ["evdi" "wacom"];

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  services.printing.enable = false;

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  services.libinput.enable = true;
  services.libinput.touchpad.tapping = true;
  services.libinput.touchpad.clickMethod = "clickfinger";

  environment.systemPackages = with pkgs; [
    tuigreet
    inputs.neovim-config.packages.${pkgs.stdenv.hostPlatform.system}.nvim

    brightnessctl
    glab
    pkgs.unstable.vscode
    pkgs.unstable.remnote
    pkgs.unstable.ladybird
  ];

  networking.firewall.allowedTCPPorts = [7236 7250];
  networking.firewall.allowedUDPPorts = [7236 5353];

  services.greetd = {
    enable = true;

    settings = {
      default_session = {
        user = "deadmade";
        command = "${pkgs.tuigreet}/bin/tuigreet
        --time
        --issue
        --asterisks
        --theme border=magenta;text=cyan;prompt=green;time=red;action=blue;button=yellow;container=black;input=red
        --cmd Hyprland";
      };
    };
  };

  hardware = {
    graphics.enable = true;
    graphics.enable32Bit = true;
  };

  system.stateVersion = "24.11";
}

{
  pkgs,
  outputs,
  inputs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

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

    outputs.nixosModules.virtualization.podman
    outputs.nixosModules.virtualization.vm
  ];

  boot.loader.grub.device = lib.mkForce "/dev/sda";

  boot.loader.grub.efiSupport = lib.mkForce false;

  environment.pathsToLink = ["/share/zsh"];

  networking.hostName = "deadServer";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.xserver.enable = false;

  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false;

  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  console.keyMap = "de";

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.deadmade = {
    isNormalUser = true;
    description = "deadmade";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  environment.systemPackages = with pkgs; [
  ];

  hardware = {
    graphics.enable = false;
  };

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  system.stateVersion = "24.11";
}

{
  config,
  pkgs,
  outputs,
  vars,
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.grub2-themes.nixosModules.default
  ];

  # Bootloader.
  boot.loader = {
    efi.canTouchEfiVariables = true;

    # Currently not working.
    grub2-theme = {
      enable = true;
      theme = "vimix";
      splashImage = null;
      footer = true;
      customResolution = "1920x1080";
    };

    grub = {
      enable = true;
      devices = ["nodev"];
      efiSupport = true;
      useOSProber = true;
    };
  };
}

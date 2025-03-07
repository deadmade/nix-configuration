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

    grub = {
      enable = true;
      devices = ["nodev"];
      efiSupport = true;
      fontSize = 48;
      useOSProber = true;
      extraEntries = ''
        menuentry "Reboot" --class restart {
            reboot
        }
        menuentry "Poweroff" --class shutdown {
            halt
        }
        menuentry "UEFI Setup" --class efi {
            fwsetup
        }
      '';
    };

    # Currently not working.
    grub2-theme = {
      enable = false; # Currently not working.
      theme = "stylish";
      icon = "color";
      footer = true;
      customResolution = "1920x1080";
    };
  };
}

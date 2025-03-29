{
  config,
  pkgs,
  outputs,
  vars,
  inputs,
  lib,
  system,
  ...
}: {
  imports = [
    inputs.distro-grub-themes.nixosModules.${"x86_64-linux"}.default
  ];

  # Bootloader.
  boot.loader = lib.mkDefault {
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
  };
  distro-grub-themes = {
    enable = true;
    theme = "nixos";
  };
}

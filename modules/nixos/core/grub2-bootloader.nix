{
  inputs,
  lib,
  ...
}: {
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
}

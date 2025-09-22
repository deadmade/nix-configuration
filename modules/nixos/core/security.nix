{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    "${inputs.nix-mineral}/nix-mineral.nix"
  ];
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;

  nix-mineral = {
    enable = true;
    };
  };
}

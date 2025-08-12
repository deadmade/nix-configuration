{pkgs, ...}: {
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;

  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
    # enabled in nix-mineral
    packages = with pkgs; [
      apparmor-profiles # Standard profiles
      apparmor-utils
    ];
  };
}

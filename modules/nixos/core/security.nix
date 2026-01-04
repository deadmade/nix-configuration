{inputs, ...}: {
  imports = [
  ];
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;
  security.apparmor.enable = true;

  #services.dbus.apparmor = "enabled";
  #security.apparmor.enableCache = true;
}

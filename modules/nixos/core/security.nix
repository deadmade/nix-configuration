{inputs, ...}: {
  imports = [
    "${inputs.nix-mineral}/nix-mineral.nix"
  ];
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;

  nix-mineral = {
    enable = true;
    overrides = {
      compatibility.allow-ip-forward = true;
      performance.allow-smt = true;
      desktop = {
        allow-multilib = true;
        home-exec = true;
        tmp-exec = true;
      };
      security = {
        disable-intelme-kmodules = true;
      };
    };
  };

  services.dbus.apparmor = "enabled";
  security.apparmor.enableCache = true;
}

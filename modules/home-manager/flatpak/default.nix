{inputs, ...}: {
  imports = [inputs.nix-flatpak.homeManagerModules.nix-flatpak];
  services.flatpak = {
    enable = true;
    uninstallUnmanaged = true;
    update.onActivation = true;
    packages = [
    ];
    overrides = {
      global = {
        Context = {
          sockets = ["wayland" "!x11" "!fallback-x11"];
          filesystems = [
            "~/.local/share/fonts:ro"
            "~/.icons:ro"
            "/nix/store:ro"
          ];
        };
      };
    };
  };
}

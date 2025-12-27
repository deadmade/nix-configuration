{inputs, ...}: {
  imports = [inputs.nix-flatpak.homeManagerModules.nix-flatpak];
  services.flatpak = {
    enable = true;
    uninstallUnmanaged = true;
    update.onActivation = true;
    packages = [
      #"md.obsidian.Obsidian"
      #"com.github.iwalton3.jellyfin-media-player"
      #"com.github.tchx84.Flatseal"
      #"io.kapsa.drive"
      #"com.rtosta.zapzap"
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

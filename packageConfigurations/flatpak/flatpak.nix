{inputs, ...}: {
  imports = [inputs.nix-flatpak.homeManagerModules.nix-flatpak];
  services.flatpak = {
    enable = true;
    uninstallUnmanaged = true;
    packages = [
      "md.obsidian.Obsidian"
      "com.github.iwalton3.jellyfin-media-player"
      "com.github.tchx84.Flatseal"
      "com.spotify.Client"
      "com.jetbrains.PyCharm-Professional"
      "com.jetbrains.Ride"
      "com.valvesoftware.Steam"
      "dev.vencord.Vesktop"
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

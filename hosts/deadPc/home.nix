{
  outputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    outputs.homeManagerProfiles.desktopGaming
  ];

  home.packages = with pkgs; [
  ];

  wayland.windowManager.hyprland = {
    settings = {
      # Drei Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an)
      # Lua config: hl.monitor() requires a table, not the legacy string form.
      monitor = [
        {
          output = "HDMI-A-1";
          mode = "1920x1080@60";
          position = "3840x0";
          scale = 1;
        } # Rechter Monitor
        {
          output = "DP-2";
          mode = "1920x1080@60";
          position = "0x0";
          scale = 1;
        } # Linker Monitor
        {
          output = "DP-3";
          mode = "1920x1080@240";
          position = "1920x0";
          scale = 1;
        } # Mittlerer Monitor
      ];
    };
  };

  gtk = {
    enable = true;
  };

  home.shellAliases = {
  };
}

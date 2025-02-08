{
  pkgs,
  lib,
  config,
  ...
}:
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "hyprland/window" ];
        modules-right = lib.mkDefault [ "tray" "memory" "cpu" "clock" ];

        tray.spacing = 10;

        clock.tooltip-format = "{:%d.%m.%Y}";
        cpu.format = "{}%  ";
        memory.format = " | {}%  ";

        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            "9" = "";
            "10" = "󰝚";
            "11" = "1";
            "12" = "2";
            "13" = "3";
            "14" = "4";
            "15" = "5";
            "16" = "6";
            "17" = "7";
            "18" = "8";
            "19" = "9";
            "20" = "10";
            "urgent" = "";
            "focused" = "";
          };
        };
      };
    };
  };
}

{
  lib,
  username,
  host,
  config,
  pkgs,
  inputs,
  ...
}:
with lib; {
  programs.fastfetch = {
    enable = true;
    package = pkgs.fastfetch;
    settings = {
      logo = {
        source = "${config.xdg.configHome}/wallpapers/deadImg.jpg";
        height = 15;
        padding = {
          left = 2;
          top = 1;
        };
      };
      display = {
        separator = " : ";
      };
      modules = [
        {
          type = "title";
          key = " ";
          format = "{6} {7} {8}";
        }
        {
          type = "custom";
          format = "┌────────────────                    ────────────────┐";
        }
        {
          type = "host";
          key = " ";
          format = "{1}";
        }
        {
          type = "os";
          key = " 󰣇";
          format = "{2}";
        }
        {
          type = "kernel";
          key = " ";
          format = "{2}";
        }
        {
          type = "packages";
          key = " 󰏗";
        }
        {
          type = "display";
          key = " 󰍹";
          format = "{1}x{2} @ {3}Hz";
        }
        {
          type = "wm";
          key = " ";
          format = "{2}";
        }
        {
          type = "shell";
          key = " ";
          format = "{6}";
        }
        {
          type = "terminal";
          key = " ";
          format = "{5}";
        }
        {
          type = "editor";
          key = " 󱩼";
          format = "{2}";
        }
        {
          type = "cpu";
          key = " ";
          format = "{1} @ {7}";
        }
        {
          type = "gpu";
          key = " 󰊴";
          format = "{2}";
        }
        {
          type = "disk";
          key = " 󱦟";
          folders = "/";
          format = "{days} days";
        }
        {
          type = "uptime";
          key = " 󱫐";
        }
        {
          type = "custom";
          format = "└────────────────                    ────────────────┘";
        }
        {
          type = "colors";
          paddingLeft = 2;
          symbol = "square";
        }
      ];
    };
  };
}

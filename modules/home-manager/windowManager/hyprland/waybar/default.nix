{
  pkgs,
  lib,
  host,
  config,
  inputs,
  ...
}: let
  betterTransition = "all 0.3s cubic-bezier(.55,-0.68,.48,1.682)";
in
  with lib; {
    home.packages = with pkgs; [
      pavucontrol
    ];

    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [
        {
          layer = "top";
          exclusive = true;
          passthrough = false;
          position = "top";
          reload_style_on_change = true;
          spacing = 0;
          fixed-center = true;
          margin-top = 6;
          margin-left = 8;
          margin-right = 8;

          modules-left = [
            "hyprland/workspaces"
            "group/hardware"
          ];

          modules-center = [
            "hyprland/window"
          ];

          modules-right = [
            "custom/exit"
            "battery"
            "tray"
            "pulseaudio"
            "custom/power"
            "clock"
            "custom/notification"
          ];

          "hyprland/workspaces" = {
            format = "{name}";
            format-icons = {
              default = " ";
              active = " ";
              urgent = " ";
            };
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
          };

          "clock" = {
            format = " {:%a, %d %b %H:%M}";
            "smooth-scrolling-threshold" = 4;
            tooltip = false;
          };

          "hyprland/window" = {
            format = "{initialTitle}";
            max-length = 30;
            separate-outputs = false;
            tooltip = false;
            rewrite = {
              kitty = " Kitty";
              foot = " Foot";
              zsh = " Terminal";
              "Friends - Discord" = " Discord";
              Spotify = " Spotify";
              "Spotify Premium" = "󰓇 Spotify";
              "Home - Mozilla Thunderbird" = "Thunderbird";
              VSCodium = "VSCode 󰨞";
            };
          };

          "group/hardware" = {
            orientation = "inherit";
            modules = [
              "cpu"
              "memory"
              "disk"
              "temperature"
            ];
          };

          "cpu" = {
            format = " {usage}%";
            interval = 1;
            max-length = 10;
            on-click = "kitty -e btop";
          };

          "disk" = {
            interval = 30;
            format = "󰋊 {free}";
            path = "/";
            tooltip = true;
            "tooltip-format" = "{used} used out of {total} on {path} ({percentage_used}%)";
          };

          "memory" = {
            states = {
              warning = 80;
            };
            interval = 5;
            format = " {}%";
            "format-alt" = " {used:0.1f}G%";
            "format-alt-click" = "click";
            tooltip = true;
            "tooltip-format" = "{used:0.1f}G/{total:0.1f}G";
            "on-click-right" = "kitty --title btop sh -c 'btop' --utf-force";
          };

          "network" = {
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            format-ethernet = " {bandwidthDownOctets}";
            format-wifi = "{icon} {signalStrength}%";
            format-disconnected = "󰤮";
            tooltip = false;
          };

          "group/trayer" = {
            orientation = "inherit";
            modules = [
              "custom/notification"
              "pulseaudio"
              "custom/power"
            ];
          };

          "custom/notification" = {
            tooltip = false;
            format = "{icon}";
            "format-icons" = {
              notification = "<span foreground='red' font-size='14pt'><sup></sup></span>";
              none = "";
              "dnd-notification" = "<span foreground='red' font-size='14pt'><sup></sup></span>";
              "dnd-none" = "";
              "inhibited-notification" = "<span foreground='red' font-size='14pt'><sup></sup></span>";
              "inhibited-none" = "";
              "dnd-inhibited-notification" = "<span foreground='red' font-size='14pt'><sup></sup></span>";
              "dnd-inhibited-none" = "";
            };
            "return-type" = "json";
            "exec-if" = "which swaync-client";
            exec = "swaync-client -swb";
            "on-click" = "swaync-client -t -sw";
            "on-click-right" = "swaync-client -d -sw";
            escape = true;
          };

          "tray" = {
            icon-size = 18;
            spacing = 8;
          };

          "pulseaudio" = {
            format = "{icon} {volume}% {format_source}";
            format-bluetooth = "{volume}% {icon} {format_source}";
            format-bluetooth-muted = " {icon} {format_source}";
            format-muted = " {format_source}";
            format-source = " {volume}%";
            format-source-muted = "";
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "sleep 0.1 && pavucontrol";
          };

          "custom/exit" = {
            tooltip = false;
            format = "";
            on-click = "sleep 0.1 && wlogout";
          };

          "custom/startmenu" = {
            tooltip = false;
            format = "";
            # exec = "rofi -show drun";
            on-click = "sleep 0.1 && rofi-launcher";
          };

          "battery" = {
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{icon} {capacity}%";
            format-charging = "󰂄  {capacity}%";
            format-plugged = "󱘖  {capacity}%";
            format-icons = [
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
            on-click = "";
            tooltip = true;
            icon-size = 55;
          };

          "temperature" = {
            #thermal-zone = 0;
            hwmon-path = "/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon1/temp1_input";
            interval = 10;
            tooltip = false;
            "thermal-zone" = 0;
            "critical-threshold" = 82;
            "format-critical" = "{icon}{temperatureC}°C";
            format = "{icon} {temperatureC}°C";
            "format-icons" = [""];

          };
        }
      ];

      style = concatStrings [
        ''
          *{
            font-family: "FiraCode Nerd Font";
            font-weight: bold;
            min-height: 0;
            color: #${config.lib.stylix.colors.base15};
            background: #${config.lib.stylix.colors.base00};
            /* set font-size to 100% if font scaling is set to 1.00 using nwg-look */
            font-size: 10px;
            font-feature-settings: '"zero", "ss01", "ss02", "ss03", "ss04", "ss05", "cv31"';
            padding: 0px;
            margin-top: 0px;
            margin-bottom: 0px;
            }



            window#waybar {
                background: transparent;
            }

            window#waybar.hidden {
                opacity: 0.2;
            }

            tooltip {
                background: alpha(#${config.lib.stylix.colors.base05}, .4);
                border-radius: 12px;
                border: 2px solid #${config.lib.stylix.colors.base05};
            }

            tooltip label {
                color: #${config.lib.stylix.colors.base15};
                margin-right: 10px;
                margin-left: 10px;
            }



            /*-----module groups----*/
            .modules-right {
                border: 0px solid ;
                border-radius: 10px;
            }

            .modules-center {
                background-color: #${config.lib.stylix.colors.base00};
                border: 0px solid ;
                border-radius: 10px;
            }

            .modules-left {
                border: 0px solid ;
                border-radius: 10px;
                margin-top: 0px;
                margin-bottom: 0px;
                padding: 0px;
            }

            #custom-logo {
                background: #${config.lib.stylix.colors.base00};
                border-radius: 10px 4px 4px 10px;
                padding-right: 4px;
                margin-right: 3px;
            }

            #workspaces {
                background: #${config.lib.stylix.colors.base00};
                padding: 0px 10px 0px 4px;
                border-radius: 4px 10px 10px 4px;
            }

            #workspaces button {
            }

            #workspaces button label {
                font-size:10px;
                min-width: 0;
                padding: 4px 16px 4px 12px;
            }

            #workspaces button.active {
                background: alpha(#${config.lib.stylix.colors.base13}, .5);
                border-radius: 8px;
                border: 3px solid @color5;
            }

            #workspaces button.focused {
                color: #a6adc8;
                background: #010409;
            }

            #workspaces button.urgent {
                background: alpha(#${config.lib.stylix.colors.base09}, .5);
                animation-name: blink;
                animation-duration: 1s;
                animation-timing-function: linear;
                animation-iteration-count: infinite;
                animation-direction: alternate;
            }

            #workspaces button:hover {
                border: 3px solid #${config.lib.stylix.colors.base06};
                border-radius: 8px;
            }

            #window,
            #custom-menu,
            #custom-lock {
                padding: 0px 10px;
            }

            #custom-menu:hover {
                border: 3px solid #${config.lib.stylix.colors.base05};
                border-radius: 10px 4px 4px 10px;
                background: alpha(#${config.lib.stylix.colors.base13}, .5);
            }

            #custom-spotify {
                color: rgb(0,0,0);
                padding: 0 20px;
                background-color:#33C668 ;
                border-radius: 15px;
            }

            #custom-spotify:hover {
              border-radius: 12px;
              border: 4px solid #1c5932;
            }

            #custom-lock:hover {
                border: 3px solid #${config.lib.stylix.colors.base05};
                border-radius: 4px 10px 10px 4px;
                background: alpha(#${config.lib.stylix.colors.base13}, .5);
            }

            @keyframes blink {
              to {
                color: #000000;
              }
            }

            #cpu {
                background: #${config.lib.stylix.colors.base10};
                font-size: 13px;
                border-radius: 10px 4px 4px 10px;
                padding: 0px 12px 0px 12px;
                margin-right: 3px;
            }

            #disk,
            #memory,
            #temperature,
            #custom-exit {
                background: #${config.lib.stylix.colors.base00};
                border-radius: 4px 4px 4px 4px;
                margin-right: 2.1px;
                padding: 0px 10px;
                font-size: 13px;
            }

            #temperature.critical {
              color: #${config.lib.stylix.colors.base06};
            }

            #tray {
                background-color: #${config.lib.stylix.colors.base00};
                padding: 0px 6px;
                border-radius: 4px 0px 0px 4px;
            }

            #network {
                background: #${config.lib.stylix.colors.base00};
                padding-left: 2px;
                padding-right: 7px;
            }

            /*.not-network {
              padding-right: 0px;
            }*/

            #custom-updates {
                background-color: #${config.lib.stylix.colors.base00};
                padding: 0px 2px;
            }

            #battery {
                background: #${config.lib.stylix.colors.base00};
                padding: 0px 4px;
                margin-bottom: 0px;
                border-radius: 0px 4px 4px 0px;
                font-size: 12px:
            }

            #battery.critical:not(.charging) {
              color: #${config.lib.stylix.colors.base06};
              margin: 5px 10px;
              animation-name: blink;
              animation-duration: 1s;
              animation-timing-function: linear;
              animation-iteration-count: infinite;
              animation-direction: alternate;
            }

            #battery.details,
            #network.details {
               all: unset;
               padding-left: 4px;
               padding-right: 4px;
               margin-bottom: -3px;
            }

            #clock {
                background-color: #${config.lib.stylix.colors.base00};
                font-size: 13px;
                padding: 0px 6px;
                border-radius: 4px 4px 4px 4px;
                margin-left: 3px;
                margin-right: 3px;
            }

            #custom-notification {
                background: #${config.lib.stylix.colors.base00};
                font-family: "NotoSansMono Nerd Font";
                border-radius: 4px 10px 10px 4px;
                padding: 0px 12px 0px 12px;
                margin-left: 0px;
            }

            #pulseaudio,
            #pulseaudio.microphone {
                background: #${config.lib.stylix.colors.base00};
                border-radius: 4px 4px 4px 4px;
                padding: 0px 14px;
                margin-right: 2.1px;
            }

            #bluetooth,
            #custom-power {
                background: #${config.lib.stylix.colors.base00};
                border-radius: 4px 4px 4px 4px;
                margin-right: 2.1px;
                padding-left: 4px;
                padding-right: 8px;
            }

            #bluetooth {
                padding: 0px 14px;
            }

            #trayer .not-trayer > *:hover {
              border: 3px solid #${config.lib.stylix.colors.base05};
              background: alpha(#${config.lib.stylix.colors.base13}, .5);
            }
        ''
      ];
    };
  }

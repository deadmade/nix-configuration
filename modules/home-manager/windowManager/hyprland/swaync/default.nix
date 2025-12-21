{
  lib,
  config,
  pkgs,
  ...
}:
with lib; {
  services.swaync = {
    enable = true;
    package = pkgs.swaynotificationcenter;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      layer-shell = true;
      control-center-layer = "overlay";
      cssPriority = "application";
      control-center-margin-top = 0;
      control-center-margin-bottom = 8;
      control-center-margin-right = 0;
      control-center-margin-left = 8;
      notification-2fa-action = true;
      notification-inline-replies = true;
      notification-window-width = 450;
      notification-icon-size = 60;
      notification-body-image-height = 180;
      notification-body-image-width = 180;
      timeout = 6;
      timeout-low = 6;
      timeout-critical = 0;
      fit-to-screen = true;
      relative-timestamps = true;
      control-center-width = 450;
      control-center-height = 1025;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = true;
      hide-on-action = true;
      script-fail-notify = true;

      widgets = [
        "title"
        "notifications"
        "mpris"
      ];

      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "󰆴";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        label = {
          max-lines = 1;
          text = "Notification Center";
        };
        mpris = {
          image-size = 96;
          image-radius = 7;
        };
        volume = {
          label = "󰕾";
          show-per-app = false;
        };
        backlight = {
          label = "";
          device = "amdgpu_bl1";
          min = 10;
        };
        buttons-grid = {
          actions = [
            {
              label = " ";
              command = "nm-connection-editor";
            }
            {
              label = "󰂯";
              command = "blueman-manager";
            }
            {
              label = "󰌾";
              command = "hyprlock";
            }
            {
              label = "󰍃";
              command = "hyprctl dispatch exit";
            }
            {
              label = "󰤄";
              command = "systemctl suspend";
            }
            {
              label = "";
              command = "obs";
            }
          ];
        };
      };
    };

    style = concatStrings [
      ''
        @define-color mpris-album-art-overlay alpha(#${config.lib.stylix.colors.base00}, 0.55);
        @define-color mpris-button-hover alpha(#${config.lib.stylix.colors.base00}, 0.50);
        @define-color bg alpha(#${config.lib.stylix.colors.base00},.5);
        @define-color bg-hover alpha(#${config.lib.stylix.colors.base00},.8);
        @define-color background-alt  alpha(#${config.lib.stylix.colors.base05}, .2);


        @keyframes fadeIn{
        0% {
            padding: 50px;
        }
        50% {
            padding: 25px;

        }
        100% {
            padding:0px;
        }
        }

        * {
          color: #${config.lib.stylix.colors.base15};

          all: unset;
          /*font-size: 14px;*/
          font-family: "FiraCode Nerd Font";
          font-weight: bold;
          transition: 200ms;

        }

        /* Avoid 'annoying' backgroud */
        .blank-window {
          background: transparent;
        }


        /* CONTROL CENTER ------------------------------------------------------------------------ */

        .control-center {
          background: alpha(#${config.lib.stylix.colors.base00}, .5);
          color: @color15;
          border-radius: 20px;
          border: 2.5px solid #${config.lib.stylix.colors.base05};
          box-shadow: 1px 1px 5px rgba(0,0,0,.65);
          margin: 18px;
          padding: 12px;
        }

        .control-center .control-center-list-placeholder {
          opacity: 0.3;
        }

        /* Notifications  */
        .floating-notifications .notification{
            animation: fadeIn .5s ease-in-out;
        }

        .control-center .notification-row .notification-background {
          background-color: @background-alt;
          border-radius: 12px;
          margin: 4px 0px;
          padding: unset;
          border: 1px solid #${config.lib.stylix.colors.base00};
        }

        .control-center .notification-row .notification-background .notification .notification-content {
          margin: 10px;
          border-radius: 12px;
          padding: 8px 6px 2px 2px;
        }

        .control-center .notification-row .notification-background .notification {
          padding: 4px;
          border-radius: 12px;
        }

        .control-center .notification-row .notification-background .notification.critical {
          background-color: #${config.lib.stylix.colors.base12};
          border-radius: 12px;
          padding: 4px;
          color: #${config.lib.stylix.colors.base12};
        }

        /* Buttons */

        .control-center .notification-row .notification-background .close-button {
          background: transparent;
          border-radius: 6px;
          color: #${config.lib.stylix.colors.base15};
          margin: 0px;
          padding: 4px;
        }

        .control-center .notification-row .notification-background .close-button:hover {
          background-color: #${config.lib.stylix.colors.base12};
        }

        .control-center .notification-row .notification-background .close-button:active {
          background-color: #${config.lib.stylix.colors.base12};
        }


        /* Notifications expanded-group */
        .notification-group-icon {
          color: #${config.lib.stylix.colors.base15};
        }

        .notification-group-collapse-button,
        .notification-group-close-all-button {
          background: transparent;
          color: #${config.lib.stylix.colors.base15};
          margin: 4px;
          border-radius: 6px;
          padding: 4px;
        }

        .notification-group-collapse-button:hover {
          background: #${config.lib.stylix.colors.base05};
        }
        .notification-group-close-all-button:hover {
          background: #${config.lib.stylix.colors.base12};
        }

        /* WIDGETS --------------------------------------------------------------------------- */

        /* Notification clear button */
        .widget-title {
          font-size: 16px;
          margin: 20px 0px 0px 0px;
          padding: 10px;
          background: @background-alt;
          border-radius: 10px 10px 0px 0px;
        }

        .widget-title button {
          background: @background-alt;
          border-radius: 6px;
          padding: 4px 16px;
        }

        .widget-title button:hover {
          background-color: #${config.lib.stylix.colors.base05};
        }

        .widget-title button:active {
          background-color: #${config.lib.stylix.colors.base12};
        }


        .widget-dnd {
          font-size: 14px;
          padding: 10px 10px 10px 10px;
          border-radius: 0px 0px 10px 10px;
          background: @background-alt;
        }

        .widget-dnd > switch {
          background: @background-alt;
          font-size: initial;
          border-radius: 8px;
          box-shadow: none;
          padding: 2px;
        }

        .widget-dnd > switch:hover {
          background: #${config.lib.stylix.colors.base05};
        }

        .widget-dnd > switch:checked {
          background: @inverse_primary;
        }

        .widget-dnd > switch:checked:hover {
          background: #${config.lib.stylix.colors.base05};
        }

        .widget-dnd > switch slider {
          background: #${config.lib.stylix.colors.base15};
          border-radius: 6px;
        }


        .widget-buttons-grid {
          font-size: 30px;
          border-radius: 12px;
          background: transparent;
        }

        .widget-buttons-grid>flowbox>flowboxchild>button {
          margin: 10px 10px;
          padding: 10px 30px 10px 30px;
          background: @background-alt;
          border-radius: 8px;
        }

        .widget-buttons-grid>flowbox>flowboxchild>button:hover {
          background: #${config.lib.stylix.colors.base05};
        }


        .widget-mpris {
        }

        .widget-mpris-player {
            padding: 16px;
            margin: 20px 0px;
            background-color: @mpris-album-art-overlay;
            border-radius: 12px;
            box-shadow: 1px 1px 5px rgba(0, 0, 0, .65);
        }

        .widget-mpris-player button {
            color: #${config.lib.stylix.colors.base15};
            text-shadow: none;
            border-radius: 15px;
            border: none;
            padding: 5px;
            margin: 5px;
            transition: all 0.5s ease;
        }

        .widget-mpris-player button:hover {
            all: unset;
            background: @bg-hover;
            text-shadow: none;
            border-radius: 15px;
            border: none;
            padding: 5px;
            margin: 5px;
            transition: all 0.5s ease;
        }

        .widget-mpris-player button:not(.selected) {
            background: transparent;
            border: 2px solid transparent;
        }
        .widget-mpris-player button:hover {
            border: 2px solid transparent;
        }

        .widget-mpris-album-art {
            border-radius: 20px;
            box-shadow: 0px 0px 5px rgba(0, 0, 0, 0.75);
        }

        .widget-mpris-title {
            font-weight: bold;
            font-size: 1.2rem;
        }

        .widget-mpris-subtitle {
            font-size: 1.05rem;
        }

        .widget-mpris-player > box > button:hover {
            background-color: @mpris-button-hover;
        }


        trough {
          border-radius: 20px;
          margin-left: 10px;
          margin-right: 5px;
          box-shadow: 0px 0px 5px rgba(0, 0, 0, .5);
          transition: all .7s ease;
        }

        trough highlight {
          background: @color5;
          padding: 5px;
          border-radius: 20px;
        }

        trough slider {
          background: transparent;
        }

        trough slider:hover {
          background: transparent;
        }

        .widget-volume {
          background-color: transparent;
          font-size: 30px;
          margin-left: 10px;
          margin-right: 10px;
          padding-bottom: 20px;
          border: 0px solid transparent;
        }

        .widget-backlight {
          background-color: transparent;
          font-size: 30px;
          margin-left: 10px;
          margin-right: 10px;
          padding-bottom: 10px;
          border-radius: 0px 0px 20px 20px;
          border: 0px solid transparent;
        }
      ''
    ];
  };
}

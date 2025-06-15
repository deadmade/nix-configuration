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
  programs.wofi = {
    enable = true;
    package = pkgs.unstable.wofi;
    settings = {
      ## General
      show = "drun";
      prompt = "";
      normal_window = true;
      layer = "overlay";
      term = "foot";
      columns = 1;

      ## Geometry
      width = "30%";
      height = "30%";
      location = "center";
      orientation = "vertical";
      halign = "fill";
      line_wrap = "off";
      dynamic_lines = false;

      ## Images
      allow_markup = true;
      allow_images = true;
      image_size = 35;

      ## Search
      exec_search = false;
      hide_search = false;
      parse_search = false;
      insensitive = false;

      ## Other
      hide_scroll = true;
      no_actions = true;
      sort_order = "default";
      gtk_dark = true;
      filter_rate = 100;

      ## Keys
      key_expand = "Tab";
      key_exit = "Escape";
    };

    style = concatStrings [
      ''
        *{
        font-family: "FiraCode Nerd Font";
        min-height: 0;
        font-size: 18px;
        font-feature-settings: '"zero", "ss01", "ss02", "ss03", "ss04", "ss05", "cv31"';
        padding: 0px;
        margin-top: 1px;
        margin-bottom: 1px;
        }

        #window {
        	background-color: alpha(#${config.lib.stylix.colors.base00}, .85);
        }

        #outer-box {
        	padding: 10px;
        }

        #input {
        	background-color: #${config.lib.stylix.colors.base12};
        	color: #${config.lib.stylix.colors.base00};
        	border-radius: 20px;
        	padding: 12px;
        }

        #scroll {
        	margin-top: 10px;
        	margin-bottom: 10px;
        }

        #img {
        	padding-right: 5px;
        	padding-left: 20px;
        	font-size: 30px;
        }

        #text {
        	color: #${config.lib.stylix.colors.base05};
        	padding-left: 10px;
        }

        #text:selected {
        	color: #${config.lib.stylix.colors.base00};
        }

        #entry {
        	padding: 5px;
        	margin-top: 5px;
        }

        #entry:selected {
        	background-color: #${config.lib.stylix.colors.base12};
        }

        #unselected {
        }

        #selected {
        }

        #input, #entry:selected {
        	border-radius: 20px;
        	border: 0px;
        }

        #input > image {
               -gtk-icon-transform:scaleX(0);
        }
      ''
    ];
  };

  wayland.windowManager.hyprland.settings = {
    "$menu" = "wofi --show drun --allow-images --no-actions";

    bind = [
      "$mainMod, Space, exec, $menu"
    ];
  };
}

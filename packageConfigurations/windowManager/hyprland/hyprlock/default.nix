{
  config,
  pkgs,
  ...
}: {
  programs.hyprlock = {
    enable = true;
    settings = {
      background = [
        {
          path = "${config.xdg.configHome}/wallpapers/deathRobot1.jpg";
          blur_passes = 2;
          contrast = 1;
          brightness = 0.5;
          vibrancy = 0.2;
          vibrancy_darkness = 0.2;
        }
      ];

      general = {
        no_fade_in = true;
        no_fade_out = true;
        hide_cursor = false;
        grace = 0;
        disable_loading_bar = true;
      };

      label = [
        {
          text = "cmd[update:1000] echo \"<span>$(date +\"%I:%M\")</span>\"";
          color = "rgba(242, 243, 244, 0.75)";
          font_size = 22;
          font_family = "JetBrains Mono";
          position = "0, 300";
          halign = "center";
          valign = "center";
        }
        {
          text = "cmd[update:1000] echo -e \"$(date +\"%A, %B %d\")\"";
          color = "rgba(242, 243, 244, 0.75)";
          font_size = 22;
          font_family = "JetBrains Mono Extrabold";
          position = "0, 200";
          halign = "center";
          valign = "center";
        }
        {
          text = "  $USER";
          color = "rgba(0, 0, 0, 1)";
          outline_thickness = 0;
          font_size = 16;
          font_family = "JetBrains Mono";
          position = "0, -150";
          halign = "center";
          valign = "center";
        }
      ];

      image = [
        {
          path = "${config.xdg.configHome}/wallpapers/AnimeDeath.jpg";
          size = 200;
          border_size = 2;
          border_color = "rgba(242, 243, 244, 0.75)";
          position = "0, 0";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          size = "250, 60";
          outline_thickness = 2;
          dots_size = 0.2; # Scale of input-field height, 0.2 - 0.8
          dots_spacing = 0.35; # Scale of dots' absolute size, 0.0 - 1.0
          dots_center = true;
          outer_color = "rgba(0, 0, 0, 0)";
          inner_color = "rgba(0, 0, 0, 0.2)";
          font_color = "rgba(242, 243, 244, 0.75)";
          fade_on_empty = false;
          rounding = -1;
          check_color = "rgb(204, 136, 34)";
          placeholder_text = "<i><span foreground=\"##ffffff99\">🔒Enter Pass</span></i>";
          hide_input = false;
          position = "0, -200";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}

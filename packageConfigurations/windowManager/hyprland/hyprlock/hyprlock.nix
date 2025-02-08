{ config, ... }:
{
  programs.hyprlock = {
    enable = true;
    settings = {
      label = [
        # Date
        {
          text = ''cmd[update:3600000] echo -e "<b> "$(date +'%A, %-d. %B %Y')" </b>"'';
          font_size = 35;
          color = "rgb(${textColor})";
          position = "0, -150";
          halign = "center";
          valign = "top";
          shadow_passes = 3;
        }
        # Time
        {
          text = ''cmd[update:3600000] echo -e "<b><big> $(date +"%H:%M") </big></b>"'';
          font_size = 94;
          #color = "rgb(${textColor})";
          position = "0, -210";
          halign = "center";
          valign = "top";
          shadow_passes = 3;
        }
      ];
    };
  };
}
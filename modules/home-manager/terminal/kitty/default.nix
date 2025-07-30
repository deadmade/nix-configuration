{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;

    settings = {
      font_family = "JetBrainsMono Nerd Font";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";

      font_size = 14;
      cursor_trail = 1;

      #background_opacity = "0.7";
      background_blur = 10;

      editor = "vim";
      tab_bar_edge = "top";
      tab_bar_margin_width = 0;
      tab_bar_margin_height = 0;
      tab_bar_style = "slant";
      tab_bar_align = "center";
      tab_bar_min_tabs = "2";
      tab_switch_strategy = "last";
      tab_powerline_style = "slanted";
      tab_title_template = "{index}:{title}";
    };

    keybindings = {
      "ctrl+shift+1" = "goto_tab 1";
      "ctrl+shift+2" = "goto_tab 2";
      "ctrl+shift+3" = "goto_tab 3";
      "ctrl+shift+4" = "goto_tab 4";
      "ctrl+shift+5" = "goto_tab 5";
      "ctrl+shift+6" = "goto_tab 6";
      "ctrl+shift+7" = "goto_tab 7";
      "ctrl+shift+8" = "goto_tab 8";
      "ctrl+shift+9" = "goto_tab 9";
      "ctrl+shift+10" = "goto_tab 0";
      "ctrl+shift+w" = "close_tab";
    };

    extraConfig = lib.mkForce ''include themes/diff-mocha.conf'';
  };

  home.file.".config/kitty/themes" = {
    source = ./themes;
    recursive = true;
  };

  home.packages = with pkgs; [
    jetbrains-mono # Ensure the font is installed
  ];
}

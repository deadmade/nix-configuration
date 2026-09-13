{
  pkgs,
  lib,
  ...
}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.unstable.ghostty;
    enableZshIntegration = true;

    settings = {
      command = "tmux new-session -A -s main";
      term = "xterm-256color";

      theme = lib.mkForce "noctalia";

      window-padding-x = 12;
      window-padding-y = 8;
      window-padding-balance = true;
      cursor-style = "block";
      mouse-hide-while-typing = true;

      window-new-tab-position = "end";

      keybind = [
        "ctrl+shift+1=goto_tab:1"
        "ctrl+shift+2=goto_tab:2"
        "ctrl+shift+3=goto_tab:3"
        "ctrl+shift+4=goto_tab:4"
        "ctrl+shift+5=goto_tab:5"
        "ctrl+shift+6=goto_tab:6"
        "ctrl+shift+7=goto_tab:7"
        "ctrl+shift+8=goto_tab:8"
        "ctrl+shift+9=goto_tab:9"
        "ctrl+shift+w=close_tab"
      ];
    };
  };

  home.packages = with pkgs; [
    jetbrains-mono
  ];
}

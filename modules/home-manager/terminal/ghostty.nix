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
      # Command to run on startup
      command = "tmux new-session -A -s main";
      term = "xterm-256color";

      # font-family, font-size and background-opacity all come from the Stylix
      # ghostty target. Do NOT restate them here: this module is also imported by
      # hosts/deadWsl/home.nix, and deadWsl has no stylix module at all,
      # so any config.stylix.* reference would break `nix flake check`.
      #
      # The theme name is forced instead. Noctalia's ghostty template renders the
      # palette, and its apply.sh greps for exactly `^theme\s*=\s*noctalia$`
      # before deciding to rewrite the file -- pre-seeding the name makes it take
      # the no-op branch instead of failing EACCES on this read-only store symlink.
      theme = lib.mkForce "noctalia";

      # Window chrome
      window-padding-x = 12;
      window-padding-y = 8;
      window-padding-balance = true;
      cursor-style = "block";
      mouse-hide-while-typing = true;

      # Tab Configuration
      window-new-tab-position = "end";

      # Keybindings (tab navigation)
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

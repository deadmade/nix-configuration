{
  # SUPER+E opens `ghostty -e yazi`. thunar was bound there for months without
  # ever being installed, so the key did nothing at all.
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      mgr = {
        show_hidden = false;
        sort_dir_first = true;
      };
    };
  };
}

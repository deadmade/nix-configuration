{pkgs, ...}: {
  programs.tmux = {
    enable = true; # Enable TMUX through Home Manager
    clock24 = true;
    shortcut = "space";
    baseIndex = 0;
    keyMode = "vi"; # Vi-style key bindings
    mouse = true; # Enable mouse support
    terminal = "tmux-256color"; # Enable true color support
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.rose-pine;
        extraConfig = ''
                  set -g @rose_pine_variant 'main' # Options are 'main', 'moon' or 'dawn'
                  set -g @rose_pine_host 'off' # Enables hostname in the status bar
                  set -g @rose_pine_hostname_short 'off' # Makes the hostname shorter by using tmux's '#h' format
                  set -g @rose_pine_date_time "%a %d %H:%M" # It accepts the date UNIX command format (man date for info)
                  set -g @rose_pine_user 'off' # Turn on the username component in the statusbar
                  set -g @rose_pine_directory 'on' # Turn on the current folder component in the status bar

                  # set -g @rose_pine_bar_bg_disable 'on' # Disables background color, for transparent terminal emulators
          # If @rose_pine_bar_bg_disable is set to 'on', uses the provided value to set the background color
          # It can be any of the on tmux (named colors, 256-color set, `default` or hex colors)
          # See more on http://man.openbsd.org/OpenBSD-current/man1/tmux.1#STYLES
                  # set -g @rose_pine_bar_bg_disabled_color_option 'default'

          # Some of these are mutually exclusive, recommended to test which one you like
                  # set -g @rose_pine_only_windows 'on' # Leaves only the window module, for max focus and space
                  set -g @rose_pine_window_status_separator "  " # Changes the default icon that appears between window names
                  set -g @rose_pine_disable_active_window_menu 'on' # Disables the menu that shows the active window on the left
                  # set -g @rose_pine_default_window_behavior 'on' # Forces tmux default window list behaviour

                  set -g @rose_pine_show_current_program 'on' # Forces tmux to show the current running program as window name
                  # set -g @rose_pine_show_pane_directory 'on' # Forces tmux to show the current directory as window name
          # Previously set -g @rose_pine_window_tabs_enabled

          # Example values for these can be:
                  set -g @rose_pine_left_separator ' -> ' # The strings to use as separators are 1-space padded
                  set -g @rose_pine_right_separator ' ' # Accepts both normal chars & nerdfont icons
                  set -g @rose_pine_field_separator '  ' # Default is two-space-padded, but can be set to anything
                  set -g @rose_pine_window_separator ' - ' # Replaces the default `:` between the window number and name

          # These are not padded
                  set -g @rose_pine_session_icon ' ' # Changes the default icon to the left of the session name
                  set -g @rose_pine_current_window_icon '' # Changes the default icon to the left of the active window name
                  set -g @rose_pine_folder_icon ' ' # Changes the default icon to the left of the current directory folder
                  set -g @rose_pine_username_icon '' # Changes the default icon to the right of the hostname
                  set -g @rose_pine_hostname_icon '󰒋' # Changes the default icon to the right of the hostname
                  set -g @rose_pine_date_time_icon '󰃰' # Changes the default icon to the right of the date module
        '';
      }
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = ''
          unbind s
          unbind r
          bind s run-shell '${tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/save.sh'
          bind r run-shell '${tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/restore.sh'
        '';
      }
    ];

    extraConfig = ''
      set -g status-position top
    '';
  };
  programs.zsh.prezto.tmux.autoStartLocal = true;
}

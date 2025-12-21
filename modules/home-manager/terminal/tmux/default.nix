{pkgs, ...}: {
  programs.tmux = {
    enable = true; # Enable TMUX through Home Manager
    clock24 = true;
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.catppuccin;
        extraConfig = ''
          # Additional tmux customizations for Catppuccin theme
          set -g @catppuccin_window_left_separator ""
          set -g @catppuccin_window_right_separator ""
          set -g @catppuccin_window_middle_separator " █"
          set -g @catppuccin_window_number_position "right"

          set -g @catppuccin_window_default_fill "number"
          set -g @catppuccin_window_default_text "#W"

          set -g @catppuccin_window_current_fill "number"
          set -g @catppuccin_window_current_text "#W"

          set -g @catppuccin_status_left_separator " "
          set -g @catppuccin_status_right_separator ""
          set -g @catppuccin_status_fill "icon"
          set -g @catppuccin_status_connect_separator "no"

          set -g @catppuccin_directory_text "#{pane_current_path}"

          set -g status-right "#{E:@catppuccin_status_directory}"
          set -ag status-right "#{E:@catppuccin_status_session}"
        '';
      }
    ];

    extraConfig = ''
      # Start counting pane and window number at 1

      set-option -g status-position top

    '';
  };
  programs.zsh.prezto.tmux.autoStartLocal = true;
}

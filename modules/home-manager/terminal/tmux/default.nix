{pkgs, ...}: {
  programs.tmux = {
    enable = true; # Enable TMUX through Home Manager
    clock24 = true;
    shortcut = "space";
    baseIndex = 1; # Start window numbering at 1
    keyMode = "vi"; # Vi-style key bindings
    mouse = true; # Enable mouse support
    terminal = "tmux-256color"; # Enable true color support

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

      # Sensible tmux defaults
      tmuxPlugins.sensible

      # Session persistence
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-dir '~/.tmux/resurrect'
        '';
      }

      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
          set -g @continuum-boot 'on'
        '';
      }

      # Better copy/paste
      {
        plugin = tmuxPlugins.yank;
        extraConfig = ''
          set -g @yank_selection_mouse 'clipboard'
        '';
      }

      # Seamless navigation between vim and tmux
      tmuxPlugins.vim-tmux-navigator
    ];

    extraConfig = ''
      # Start counting pane and window number at 1
      set -g base-index 1
      setw -g pane-base-index 1

      # Status bar configuration
      set-option -g status-position top

      # Better split pane bindings
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Easy config reload
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Pane navigation (vim-style)
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Pane resizing
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Enable true color support
      set -ga terminal-overrides ",xterm-256color:Tc"

      # Increase scrollback buffer
      set -g history-limit 50000

      # Reduce escape time for faster command sequences
      set -s escape-time 0

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Activity monitoring
      setw -g monitor-activity on
      set -g visual-activity off
    '';
  };
  programs.zsh.prezto.tmux.autoStartLocal = true;
}

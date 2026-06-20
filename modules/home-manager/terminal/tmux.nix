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
        # Catppuccin Mocha status bar — matches the global Stylix scheme.
        plugin = tmuxPlugins.catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'mocha'
          set -g @catppuccin_window_status_style 'none'
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
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];

    extraConfig = ''
      set -g status-position top
    '';
  };
  programs.zsh.prezto.tmux.autoStartLocal = true;
}

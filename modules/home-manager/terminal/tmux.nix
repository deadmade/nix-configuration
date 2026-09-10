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

      # Noctalia's tmux template renders themes/noctalia.conf from the wallpaper
      # palette. Its apply.sh deletes any existing noctalia source-file line,
      # re-appends it at EOF, then `cmp -s` -- so if this identical line is
      # already last, no write is attempted and the script proceeds to
      # live-reload running servers instead of dying EACCES on this store symlink.
      #
      # Must be byte-exact and LAST. XDG_CONFIG_HOME is unset in this session, so
      # apply.sh takes its $HOME branch and emits exactly this string.
      source-file -q "$HOME/.config/tmux/themes/noctalia.conf"
    '';
  };
  programs.zsh.prezto.tmux.autoStartLocal = true;
}

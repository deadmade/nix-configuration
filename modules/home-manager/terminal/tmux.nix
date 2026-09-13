{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    clock24 = true;
    shortcut = "space";
    baseIndex = 0;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
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
      source-file -q "$HOME/.config/tmux/themes/noctalia.conf"
    '';
  };
  programs.zsh.prezto.tmux.autoStartLocal = true;
}

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
      }

      # Sensible tmux defaults
      tmuxPlugins.sensible
    ];

    extraConfig = ''
      # Start counting pane and window number at 1
      set -g base-index 1
      setw -g pane-base-index 1
    '';
  };
  programs.zsh.prezto.tmux.autoStartLocal = true;
}

{pkgs, ...}: {
  programs.bat.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
  };

  # FZF fuzzy finder with Catppuccin theme
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;

    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
      "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8"
      "--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
      "--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
    ];

    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetOptions = [
      "--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
    ];

    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
    changeDirWidgetOptions = [
      "--preview 'eza --tree --color=always {} | head -200'"
    ];

    historyWidgetOptions = [
      "--sort"
      "--exact"
    ];
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    syntaxHighlighting.highlighters = [
      "main"
      "brackets"
      "pattern"
      "root"
      "line"
    ];

    # Enhanced history configuration
    history = {
      size = 50000;
      save = 50000;
      path = "$HOME/.zsh_history";
      extended = true; # Save timestamps
      ignoreDups = true;
      ignoreSpace = true;
      share = true; # Share history between sessions
      expireDuplicatesFirst = true;
    };

    historySubstringSearch = {
      enable = true;
    };

    shellAliases = {
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
      cat = "bat";

      # Tmux aliases
      ta = "tmux attach -t";
      ts = "tmux new-session -s";
      tl = "tmux list-sessions";
      tkss = "tmux kill-session -t";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "gitfast"
        #"docker"
        #"docker-compose"
        "dotnet"
        "sudo"
        "dirhistory"
        "history"
        "vi-mode"
      ];
      #theme = "catppuccin";
    };

    # FZF keybinding fix and additional configurations
    initExtra = ''
      # FZF keybinding fix - rebind after zsh defaults load
      if [ -n "''${commands[fzf-share]}" ]; then
        source "$(fzf-share)/key-bindings.zsh"
      fi

      # Ensure FZF Ctrl+R binding takes precedence
      bindkey '^R' fzf-history-widget

      # Tmux session management functions

      # Smart tmux session creator - creates or attaches to session
      function tm() {
        if [ -n "$1" ]; then
          tmux new-session -As "$1"
        else
          local session_name=$(basename "$(pwd)" | tr '.' '_')
          tmux new-session -As "$session_name"
        fi
      }

      # Tmux session selector with FZF
      function tms() {
        local session
        session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --exit-0) || return
        if [ -n "$TMUX" ]; then
          tmux switch-client -t "$session"
        else
          tmux attach-to-session -t "$session"
        fi
      }

      # Create or attach to project-based tmux session with FZF
      function tp() {
        local project_dir
        project_dir=$(fd --type d --max-depth 3 --hidden --follow --exclude .git . "$HOME" | fzf --exit-0) || return

        if [ -z "$project_dir" ]; then
          return
        fi

        local session_name=$(basename "$project_dir" | tr '.' '_')

        if ! tmux has-session -t "$session_name" 2>/dev/null; then
          tmux new-session -ds "$session_name" -c "$project_dir"
        fi

        if [ -n "$TMUX" ]; then
          tmux switch-client -t "$session_name"
        else
          tmux attach-to-session -t "$session_name"
        fi
      }

      # Kill tmux session with FZF selector (supports multi-select)
      function tmk() {
        local sessions
        sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --exit-0 --multi) || return
        echo "$sessions" | xargs -I {} tmux kill-session -t {}
      }

      # Ghostty-specific optimizations
      if [ "$TERM_PROGRAM" = "ghostty" ]; then
        # Ghostty supports true color
        export COLORTERM=truecolor

        # Notify on long-running commands (Ghostty notification support)
        function notify_when_done() {
          "$@"
          local exit_code=$?
          if [ $exit_code -eq 0 ]; then
            echo -e "\033]777;notify;Command completed;$@\033\\"
          else
            echo -e "\033]777;notify;Command failed;$@\033\\"
          fi
          return $exit_code
        }
        alias nwd='notify_when_done'
      fi

      # Environment info function (useful for debugging)
      function envinfo() {
        echo "Terminal: $TERM"
        echo "Term Program: ''${TERM_PROGRAM:-not set}"
        echo "Ghostty: $(command -v ghostty || echo 'not found')"
        echo "Tmux: $(tmux -V 2>/dev/null || echo 'not in tmux')"
        echo "Tmux session: ''${TMUX:+$(tmux display-message -p '#S' 2>/dev/null || echo 'N/A')}"
        echo "Hostname: $(hostname)"
        echo "Shell: $SHELL"
      }
    '';
  };

  # Required packages for FZF
  home.packages = with pkgs; [
    fd # Better find alternative for FZF
    ripgrep # Better grep
  ];
}

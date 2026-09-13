{pkgs, ...}: {
  programs.bat = {
    enable = true;

    config.theme = "noctalia";
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    history = {
      size = 10000;
      save = 10000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
      extended = true;
    };

    syntaxHighlighting.highlighters = [
      "main"
      "brackets"
      "pattern"
      "root"
      "line"
    ];

    shellAliases = {
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
      cat = "bat";
    };

    initContent = ''
      [[ -f ~/.config/fzf/themes/noctalia.sh ]] && source ~/.config/fzf/themes/noctalia.sh
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "gitfast"
        "dotnet"
        "sudo"
        "dirhistory"
        "history"
        "colored-man-pages"
        "extract"
        "fzf"
      ];
    };
  };

  home.packages = with pkgs; [
  ];
}

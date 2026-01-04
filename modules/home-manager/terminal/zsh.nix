{pkgs, ...}: {
  programs.bat.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    # Colors are managed by Stylix
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
        "command-not-found"
        "fzf"
      ];
    };
  };

  home.packages = with pkgs; [
  ];
}

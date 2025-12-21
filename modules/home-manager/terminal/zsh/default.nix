{
  inputs,
  pkgs,
  ...
}: {
  programs.bat.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
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
        #"docker"
        #"docker-compose"
        "dotnet"
        "sudo"
        "dirhistory"
        "history"
      ];
      #theme = "catppuccin";
    };
  };
}

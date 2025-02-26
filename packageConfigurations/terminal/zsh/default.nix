{
  inputs,
  pkgs,
  ...
}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;

    syntaxHighlighting.enable = true;
    syntaxHighlighting.highlighters = [
      "main"
      "brackets"
      "pattern"
      "root"
      "line"
    ];

    oh-my-zsh = {
      enable = true;
      plugins = [
        "gitfast"
        "colored-man-pages"
        "colorize"
        "command-not-found"
        "docker"
        "dotnet"
        "git-auto-fetch"
        "gh"
        "web-search"
        "sudo"
      ];
      #theme = "catppuccin";
    };
  };
}

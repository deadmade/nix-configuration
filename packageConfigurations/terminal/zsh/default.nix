{
  inputs,
  pkgs,
  ...
}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    package = pkgs.unstable.zsh;

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

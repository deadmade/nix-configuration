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
        "docker"
        "docker-compose"
        "dotnet"
        "sudo"
      ];
      #theme = "catppuccin";
    };
  };
}

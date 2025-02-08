{pkgs, ...}: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    extensions = with pkgs.vscode-extensions; [
      # Theme
      dracula-theme.theme-dracula

      # Productivity
      vscodevim.vim
      yzhang.markdown-all-in-one
      eamodio.gitlens
      esbenp.prettier-vscode

      # Nix Support
      jnoortheen.nix-ide
    ];
  };
}

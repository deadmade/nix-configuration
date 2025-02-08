{pkgs-unstable, ...}: {
  programs.vscode = {
    enable = true;
    package = pkgs-unstable.vscodium;
    extensions = with pkgs-unstable.vscode-extensions; [
      # Theme
      dracula-theme.theme-dracula

      # Productivity
      vscodevim.vim
      yzhang.markdown-all-in-one
      eamodio.gitlens
      esbenp.prettier-vscode

      # Nix Support
      jnoortheen.nix-ide

      github.copilot
      github.copilot-chat
    ];
  };
}

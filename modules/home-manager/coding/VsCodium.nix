{
  pkgs,
  lib,
  ...
}: {
  programs.vscode = {
    enable = true;
    package = pkgs.unstable.vscodium;
    profiles.default = {
      enableUpdateCheck = false;
      extensions = with pkgs.unstable.vscode-extensions; [
        # Theme
        catppuccin.catppuccin-vsc

        # Productivity
        vscodevim.vim
        yzhang.markdown-all-in-one
        eamodio.gitlens
        esbenp.prettier-vscode

        ms-azuretools.vscode-docker
        #chrmarti.regex
        #wayou.vscode-todo-highlight
        oderwat.indent-rainbow
        kamikillerto.vscode-colorize

        # Nix Support
        jnoortheen.nix-ide

        github.copilot
        github.copilot-chat
      ];

      userSettings = lib.mkForce {
        #Disable AutoUpdate
        "extensions.autoCheckUpdates" = false;
        "extensions.autoUpdate" = false;

        "workbench.colorTheme" = "Catppuccin Frappé";
        "files.autoSave" = "onFocusChange";
      };
    };
  };
}

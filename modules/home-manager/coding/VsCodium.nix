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
        esbenp.prettier-vscode

        ms-azuretools.vscode-docker
        #chrmarti.regex
        #wayou.vscode-todo-highlight
        oderwat.indent-rainbow
        kamikillerto.vscode-colorize

        vscode-icons-team.vscode-icons

        ms-python.python
        tamasfe.even-better-toml

        mkhl.direnv
        ms-toolsai.jupyter
        redhat.vscode-yaml
        ms-toolsai.datawrangler
        arrterian.nix-env-selector
        jnoortheen.nix-ide
        mkhl.direnv

        ms-toolsai.datawrangler
        ms-toolsai.jupyter
        #ms-toolsai.vscode-jupyter-powertoys
        #ms-toolsai.jupyter-hub
        ms-toolsai.jupyter-renderers
      ];

      userSettings = lib.mkForce {
        #Disable AutoUpdate
        "extensions.autoCheckUpdates" = false;
        "extensions.autoUpdate" = false;

        "workbench.colorTheme" = "Catppuccin Frappé";
        "files.autoSave" = "onFocusChange";
        "autoType.serverCommand" = "/home/deadmade/python-auto-type/auto_type/.venv/bin/auto-type-server";

        "editor.inlayHints.enabled" = "on";
        "editor.inlayHints.fontSize" = "12";
        "editor.inlayHints.padding" = "true";
        "explorer.excludeGitIgnore" = true;
        "direnv.restart.automatic" = true;

        "nix.enableLanguageServer" = true;
      };
    };
  };
}

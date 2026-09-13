{
  pkgs,
  lib,
  ...
}: {
  programs.vscodium = {
    enable = false;
    package = pkgs.unstable.vscodium;
    profiles.default = {
      enableUpdateCheck = false;
      extensions = with pkgs.unstable.vscode-extensions; [
        catppuccin.catppuccin-vsc

        vscodevim.vim
        yzhang.markdown-all-in-one

        ms-python.python

        mkhl.direnv
        redhat.vscode-yaml
        arrterian.nix-env-selector
      ];

      userSettings = lib.mkForce {
        "extensions.autoCheckUpdates" = false;
        "extensions.autoUpdate" = false;

        "workbench.colorTheme" = "Catppuccin Mocha";
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

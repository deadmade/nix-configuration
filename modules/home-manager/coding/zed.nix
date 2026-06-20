{
  pkgs,
  lib,
  ...
}: {
  programs.zed-editor = {
    enable = true;
    package = pkgs.unstable.zed-editor;

    extensions = [
      "catppuccin"
      "nix"
      "python"
      "yaml"
      "html"
      "direnv"
      "toml"
      "git-firefly"
      "dockerfile"
      "sql"
      "lua"
      "c#"
      "xml"
      "latex"
      "csv"
      "docker-compose"
    ];

    userSettings = {
      vim_mode = true;
      theme = lib.mkForce "Catppuccin Mocha";
      autosave = "on_focus_change";

      inlay_hints = {
        enabled = true;
        font_size = 12;
      };
    };
  };
}

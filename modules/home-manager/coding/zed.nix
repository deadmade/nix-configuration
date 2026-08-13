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
      "catppuccin-icons"
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
      "xml"
      "latex"
      "csv"
      "docker-compose"
      "csharp"
      "log"
      "make"
      "zig"
      "mcp-server-context7"
      "graphql"
      "codebook"
      "ini"
      "python-requirements"
      "env"
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

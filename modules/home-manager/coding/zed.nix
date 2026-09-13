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
      base_keymap = "JetBrains";

      theme = lib.mkForce "Noctalia Dark";
      autosave = "on_focus_change";
      cli_default_open_behavior = "existing_window";

      icon_theme = {
        mode = "dark";
        light = "Zed (Default)";
        dark = "Catppuccin Mocha";
      };

      inlay_hints = {
        enabled = true;
        font_size = 12;
      };

      project_panel.hide_gitignore = true;
      tab_bar.show = true;

      title_bar = {
        show_menus = true;
        show_branch_status_icon = false;
      };

      disable_ai = false;

      agent = {
        sidebar_side = "right";
        favorite_models = [];
        model_parameters = [];
      };

      agent_servers."claude-acp" = {
        type = "registry";
        default_config_options.fast = false;
      };
    };
  };
}

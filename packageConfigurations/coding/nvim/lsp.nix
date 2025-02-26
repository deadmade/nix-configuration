{
  programs.nixvim.plugins = {
    lsp = {
      enable = true;
      inlayHints = true;

      servers = {
        marksman.enable = true; # Markdown
        nil_ls.enable = true; # Nix
        vimls.enable = true; # Vim
        dockerls.enable = true; # Dockerfile
        #gitsigns.enable = true; # Gitignore, git_config, gitattributes
        texlab.enable = true; # Latex
      };
    };

    neo-tree = {
      enable = true;
      enableDiagnostics = false;
      enableGitStatus = true;
      enableModifiedMarkers = true;
      enableRefreshOnWrite = true;
      closeIfLastWindow = true;
      popupBorderStyle = "rounded"; # Type: null or one of “NC”, “double”, “none”, “rounded”, “shadow”, “single”, “solid” or raw lua code
      buffers = {
        bindToCwd = false;
        followCurrentFile = {
          enabled = true;
        };
      };
      window = {
        width = 40;
        height = 15;
        autoExpandWidth = false;
        mappings = {
          "<space>" = "none";
        };
      };
    };

    todo-comments = {
      enable = true;
      settings.colors = {
        error = ["DiagnosticError" "ErrorMsg" "#DC2626"];
        warning = ["DiagnosticWarn" "WarningMsg" "#FBBF24"];
        info = ["DiagnosticInfo" "#2563EB"];
        hint = ["DiagnosticHint" "#10B981"];
        default = ["Identifier" "#7C3AED"];
        test = ["Identifier" "#FF00FF"];
      };
    };
  };
}

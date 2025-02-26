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

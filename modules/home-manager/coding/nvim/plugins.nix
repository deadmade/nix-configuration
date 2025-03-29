{pkgs, ...}: {
  programs.nixvim.plugins = {
    lualine.enable = true;
    web-devicons.enable = true;

    treesitter = {
      enable = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        markdown
        nix
        vim
        dockerfile
        gitignore
        git_config
        gitattributes
        toml
        latex
      ];
      settings = {
        highlight = {
          enable = true;
          disable = [
            "latex"
            "markdown"
          ];
          auto_install = true;
          incremental_selection.enable = true;
        };
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

    vimtex = {
      enable = true;
      texlivePackage = pkgs.unstable.texlive.combined.scheme-full;
    };

    obsidian = {
      enable = true;
      autoLoad = true;

      settings = {
        completion = {
          min_chars = 2;
          nvim_cmp = true;
        };
        workspaces = [
          {
            name = "Tinf2023-LessonSummaries";
            path = "/mnt/c/Users/manue/Documents/GitHub/Tinf2023-LessonSummaries";
          }
        ];
        ui = {
          enable = true;
        };
      };
    };

    lspkind.enable = true;
    luasnip.enable = true;
    cmp_luasnip.enable = true;

    cmp = {
      enable = true;
      autoEnableSources = true;
      autoLoad = true;

      settings.sources = [
        {name = "luasnip";}
        {name = "nvim_lsp";}
        {name = "nvim_lsp_signature_help";}
        {name = "path";}
        {name = "buffer";}
      ];
    };
  };
}

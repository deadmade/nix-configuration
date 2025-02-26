{pkgs, ...}: {
  programs.nixvim.plugins = {
    lualine.enable = true;

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
    };
  };
}

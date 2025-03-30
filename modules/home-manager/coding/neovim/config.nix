{
  config,
  lib,
  inputs,
  ...
}: let
  utils = inputs.nixCats.utils;
in {

  imports = [
    inputs.nixCats.homeModule
  ];

  # this value, nixCats is the defaultPackageName you pass to mkNixosModules
  # it will be the namespace for your options.
  nixCats = {
    enable = true;
    # nixpkgs_version = inputs.nixpkgs;
    # this will add the overlays from ./overlays and also,
    # add any plugins in inputs named "plugins-pluginName" to pkgs.neovimPlugins
    # It will not apply to overall system, just nixCats.
    addOverlays =
      /*
      (import ./overlays inputs) ++
      */
      [
        (utils.standardPluginOverlay inputs)
      ];
    # see the packageDefinitions below.
    # This says which of those to install.
    packageNames = ["myHomeModuleNvim"];

    luaPath = ./.;

    # the .replace vs .merge options are for modules based on existing configurations,
    # they refer to how multiple categoryDefinitions get merged together by the module.
    # for useage of this section, refer to :h nixCats.flake.outputs.categories
    categoryDefinitions.replace = {
      pkgs,
      settings,
      categories,
      extra,
      name,
      mkPlugin,
      ...
    } @ packageDef: {
      # to define and use a new category, simply add a new list to a set here,
      # and later, you will include categoryname = true; in the set you
      # provide when you build the package using this builder function.
      # see :help nixCats.flake.outputs.packageDefinitions for info on that section.

      # lspsAndRuntimeDeps:
      # this section is for dependencies that should be available
      # at RUN TIME for plugins. Will be available to PATH within neovim terminal
      # this includes LSPs
      lspsAndRuntimeDeps = with pkgs; {
        general = [
          universal-ctags
          ripgrep
          fd
          stdenv.cc.cc
          nix-doc
          lua-language-server
          nixd
          stylua
        ];
        kickstart-debug = [
          delve
        ];
        kickstart-lint = [
          markdownlint-cli
        ];
      };

      # This is for plugins that will load at startup without using packadd:
      startupPlugins = with pkgs.vimPlugins; {
        general = [
          vim-sleuth
          lazy-nvim
          comment-nvim
          gitsigns-nvim
          which-key-nvim
          telescope-nvim
          telescope-fzf-native-nvim
          telescope-ui-select-nvim
          nvim-web-devicons
          plenary-nvim
          nvim-lspconfig
          lazydev-nvim
          fidget-nvim
          conform-nvim
          nvim-cmp
          luasnip
          cmp_luasnip
          cmp-nvim-lsp
          cmp-path
          tokyonight-nvim
          todo-comments-nvim
          mini-nvim
          nvim-treesitter.withAllGrammars
          # This is for if you only want some of the grammars
          # (nvim-treesitter.withPlugins (
          #   plugins: with plugins; [
          #     nix
          #     lua
          #   ]
          # ))
        ];
        kickstart-debug = [
          nvim-dap
          nvim-dap-ui
          nvim-dap-go
          nvim-nio
        ];
        kickstart-indent_line = [
          indent-blankline-nvim
        ];
        kickstart-lint = [
          nvim-lint
        ];
        kickstart-autopairs = [
          nvim-autopairs
        ];
        kickstart-neo-tree = [
          neo-tree-nvim
          nui-nvim
          # nixCats will filter out duplicate packages
          # so you can put dependencies with stuff even if they're
          # also somewhere else
          nvim-web-devicons
          plenary-nvim
        ];
      };

      # not loaded automatically at startup.
      # use with packadd and an autocommand in config to achieve lazy loading
      optionalPlugins = {
      };

      # shared libraries to be added to LD_LIBRARY_PATH
      # variable available to nvim runtime
      sharedLibraries = {
        general = with pkgs; [];
      };

      # environmentVariables:
      # this section is for environmentVariables that should be available
      # at RUN TIME for plugins. Will be available to path within neovim terminal
      environmentVariables = {
        # test = {
        #   CATTESTVAR = "It worked!";
        # };
      };

      # categories of the function you would have passed to withPackages
      extraPython3Packages = {
        # test = [ (_:[]) ];
      };

      # If you know what these are, you can provide custom ones by category here.
      # If you dont, check this link out:
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/make-wrapper.sh
      extraWrapperArgs = {
        # test = [
        #   '' --set CATTESTVAR2 "It worked again!"''
        # ];
      };

      # populates $LUA_PATH and $LUA_CPATH
      extraLuaPackages = {
        test = [(_: [])];
      };
    };

    # see :help nixCats.flake.outputs.packageDefinitions
    packageDefinitions.replace = {
      # These are the names of your packages
      # you can include as many as you wish.
      myHomeModuleNvim = {pkgs, ...}: {
        # they contain a settings set defined above
        # see :help nixCats.flake.outputs.settings
        settings = {
          wrapRc = true;
          # unwrappedCfgPath = "/path/to/here";
          # IMPORTANT:
          # your alias may not conflict with your other packages.
          aliases = ["vi" "vim" "homeVim"];
          # neovim-unwrapped = inputs.neovim-nightly-overlay.packages.${pkgs.system}.neovim;
        };
        # and a set of categories that you want
        # (and other information to pass to lua)
        # and a set of categories that you want
        categories = {
          general = true;
          gitPlugins = true;
          customPlugins = true;
          test = true;

          kickstart-autopairs = true;
          kickstart-neo-tree = true;
          kickstart-debug = true;
          kickstart-lint = true;
          kickstart-indent_line = true;

          # this kickstart extra didnt require any extra plugins
          # so it doesnt have a category above.
          # but we can still send the info from nix to lua that we want it!
          kickstart-gitsigns = true;

          # we can pass whatever we want actually.
          have_nerd_font = false;

          example = {
            youCan = "add more than just booleans";
            toThisSet = [
              "and the contents of this categories set"
              "will be accessible to your lua with"
              "nixCats('path.to.value')"
              "see :help nixCats"
              "and type :NixCats to see the categories set in nvim"
            ];
          };
        };
        # anything else to pass and grab in lua with `nixCats.extra`
        extra = {
          nixdExtras.nixpkgs = ''import ${pkgs.path} {}'';
        };
      };
    };
  };
}

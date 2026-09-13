{
  description = "Deadmades's NixOS config";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    flake-parts = {
      type = "github";
      owner = "hercules-ci";
      repo = "flake-parts";
    };

    nixpkgs = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "nixos-26.05";
    };

    nixpkgs-unstable = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };

    nix-flatpak = {
      type = "github";
      owner = "gmodena";
      repo = "nix-flatpak";
      ref = "latest";
    };

    nixos-wsl = {
      type = "github";
      owner = "nix-community";
      repo = "NixOS-WSL";
      ref = "release-26.05";
    };

    home-manager = {
      type = "github";
      owner = "nix-community";
      repo = "home-manager";
      ref = "release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware = {
      type = "github";
      owner = "nixos";
      repo = "nixos-hardware";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      type = "github";
      owner = "nix-community";
      repo = "stylix";
      ref = "release-26.05";
    };

    neovim-config = {
      type = "github";
      owner = "deadmade";
      repo = "neovim-configuration";
    };

    #neovim-config = {
    #  url = "git+file:/home/deadmade/neovim-configuration";
    #};

    nix-jetbrains-plugins = {
      type = "github";
      owner = "theCapypara";
      repo = "nix-jetbrains-plugins";
    };

    solaar = {
      type = "github";
      owner = "Svenum";
      repo = "Solaar-Flake";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      type = "github";
      owner = "cachix";
      repo = "git-hooks.nix";
      ref = "master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      type = "github";
      owner = "numtide";
      repo = "llm-agents.nix";
      ref = "main";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };

    hyprsplit = {
      url = "github:shezdy/hyprsplit";
      flake = false;
    };

    chiplang-nix = {
      type = "github";
      owner = "deadmade";
      repo = "chiplang-nix";
    };

    gitluxe.url = "git+file:///home/deadmade/gitluxe";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixsecauditor = {
      url = "github:unnamed-systems/nixsecauditor";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-mineral = {
      type = "github";
      owner = "cynicsketch";
      repo = "nix-mineral";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      type = "github";
      owner = "serokell";
      repo = "deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    multiverse = {
      type = "github";
      owner = "fzakaria";
      repo = "nixpkgs-multiverse";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./flake/modules/constants.nix
        ./flake/modules/exports.nix
        ./flake/modules/hosts.nix
        ./flake/modules/home.nix
        ./flake/modules/per-system.nix
        ./flake/modules/deploy.nix
      ];
    };
}

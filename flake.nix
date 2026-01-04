{
  description = "Deadmades's NixOS config";

  # Set up caches for faster builds
  nixConfig = {
    extra-substituters = [
      "https://deadcache.cachix.org"
      # "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "deadcache.cachix.org-1:k8yt2hshOzIWYT5B5Buj2/hK6bu2haiTz9juF4ERvcw="
      # "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "nixos-25.11";
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
      ref = "release-25.11";
    };

    home-manager = {
      type = "github";
      owner = "nix-community";
      repo = "home-manager";
      ref = "release-25.11";
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
      ref = "release-25.11";
    };

    #neovim-config = {
    #  type = "github";
    #  owner = "deadmade";
    #  repo = "neovim-configuration";
    #};

    neovim-config = {
      url = "git+file:/home/deadmade/neovim-configuration";
    };

    nvix.url = "github:niksingh710/nvix";

    arion = {
      type = "github";
      owner = "hercules-ci";
      repo = "arion";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      type = "github";
      owner = "Mic92";
      repo = "sops-nix";
      ref = "master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixcord = {
      type = "github";
      owner = "KaylorBen";
      repo = "nixcord";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    colmena = {
      type = "github";
      owner = "zhaofengli";
      repo = "colmena";
      ref = "main";
    };

    llm-agents = {
      type = "github";
      owner = "numtide";
      repo = "llm-agents.nix";
      ref = "main";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    vars = import ./variables.nix;
  in {
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};

    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;

    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    nixosConfigurations = {
      deadConvertible = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs vars;};
        modules = [
          ./hosts/deadConvertible/config.nix
        ];
      };

      deadPc = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs vars;};
        modules = [
          ./hosts/deadPc/config.nix
        ];
      };

      deadWsl = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs vars;};
        modules = [
          ./hosts/deadWsl/config.nix
        ];
      };

      # deadServer = nixpkgs.lib.nixosSystem {
      #   specialArgs = {inherit inputs outputs vars systems;};
      #   modules = [
      #     ./hosts/deadServer/config.nix
      #   ];
      # };

      # Regular Pi configuration (not for SD image building)
      deadPi = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs vars;};
        system = "aarch64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix"
          ./hosts/deadPi
          {
            sdImage.compressImage = false;
          }
        ];
      };
    };

    # home-manager switch --flake .#deadmade@<host>
    homeConfigurations = {
      "${vars.username}@deadConvertible" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs vars;};
        modules = [
          ./hosts/deadConvertible/home.nix
        ];
      };
      "${vars.username}@deadWsl" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs vars;};
        modules = [
          ./hosts/deadWsl/home.nix
        ];
      };
      "${vars.username}@deadPc" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs vars systems;};
        modules = [
          ./hosts/deadPc/home.nix
        ];
      };
    };

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      pre-commit-check = inputs.git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          # Nix formatting with alejandra (same as `nix fmt .`)
          alejandra.enable = true;

          # Remove dead code
          #deadnix.enable = true;

          # Validate flake
          flake-checker.enable = false;

          check-merge-conflicts.enable = true;
          convco.enable = true;
          check-added-large-files.enable = true;
          end-of-file-fixer.enable = true;
          trufflehog.enable = true;
        };
      };
    in {
      default = pkgs.mkShell {
        inherit (pre-commit-check) shellHook;
        buildInputs = pre-commit-check.enabledPackages;
        packages = with pkgs; [
          lazygit
          sops
          cachix
          vulnix
          age
          colmena
        ];
      };
    });
  };
}

{
  description = "Deadmades's NixOS great config";

  # Set up caches for faster builds
  nixConfig = {
    extra-substituters = [
      "https://deadcache.cachix.org"
      "https://nix-community.cachix.org"
      "https://chaotic-nyx.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "deadcache.cachix.org-1:k8yt2hshOzIWYT5B5Buj2/hK6bu2haiTz9juF4ERvcw="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
    ];
  };

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "release-25.05";
    };

    nixpkgs-unstable = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };

    chaotic = {
      type = "github";
      owner = "chaotic-cx";
      repo = "nyx";
      ref = "nyxpkgs-unstable";
    };

    nixos-generators = {
      type = "github";
      owner = "nix-community";
      repo = "nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
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
      ref = "main";
    };

    home-manager = {
      type = "github";
      owner = "nix-community";
      repo = "home-manager";
      ref = "release-25.05";
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
      ref = "release-25.05";
    };

    neovim-config = {
      type = "github";
      owner = "deadmade";
      repo = "neovim-configuration";
    };

    #neovim-config = {
    # url = "git+file:/home/deadmade/neovim-configuration";
    #};

    distro-grub-themes = {
      type = "github";
      owner = "AdisonCavani";
      repo = "distro-grub-themes";
    };

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

      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixcord = {
      type = "github";
      owner = "xaiyadev";
      repo = "nixcord";
      ref = "fix/user-cfg-no-option";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-mineral = {
      type = "github";
      owner = "cynicsketch";
      repo = "nix-mineral";
      flake = false;
    };

    nix-jetbrains-plugins = {
      type = "github";
      owner = "theCapypara";
      repo = "nix-jetbrains-plugins";
    };

    solaar = {
      #url = "https://flakehub.com/f/Svenum/Solaar-Flake/*.tar.gz"; # For latest stable version
      type = "github";
      owner = "Svenum";
      repo = "Solaar-Flake";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-raspberrypi = {
      type = "github";
      owner = "nvmd";
      repo = "nixos-raspberrypi";
      ref = "main";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixos-wsl,
    nixos-raspberrypi,
    nixos-generators,
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
    pkgs = import nixpkgs-unstable {system = "x86_64-linux";};
  in {
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};

    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;

    # Custom modules
    customModules = import ./custom-modules;

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

      deadServer = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs vars systems;};
        modules = [
          ./hosts/deadServer/config.nix
        ];
      };

      # build with nix build .#nixosConfigurations.deadPi.config.system.build.sdImage
      deadPi = nixos-raspberrypi.lib.nixosSystemFull {
        specialArgs = inputs;
        system = "aarch64-linux";
        modules = [
          ./hosts/deadPi
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

    # nix build .#deadPcIso
    packages.x86_64-linux = {
      deadPcIso = nixos-generators.nixosGenerate {
        specialArgs = {inherit inputs outputs vars;};
        system = "x86_64-linux";
        modules = [
          ./hosts/deadPc/config.nix
        ];
        format = "install-iso";
      };
      deadConvertibleIso = nixos-generators.nixosGenerate {
        specialArgs = {inherit inputs outputs vars;};
        system = "x86_64-linux";
        modules = [
          ./hosts/deadConvertible/config.nix
        ];
        format = "install-iso";
      };
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = with pkgs; [
        lazygit
        sops
        cachix
        vulnix
        age
      ];

      shellHook = ''
      '';
    };
  };
}

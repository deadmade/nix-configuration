{
  description = "Deadmades's NixOS great config";

  # Set up caches for faster builds
  nixConfig = {
    extra-substituters = [
      "https://deadcache.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "deadcache.cachix.org-1:k8yt2hshOzIWYT5B5Buj2/hK6bu2haiTz9juF4ERvcw="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
    };

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware.url = "github:nixos/nixos-hardware";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:nix-community/stylix/release-25.05";

    neovim-config = {
      url = "github:deadmade/neovim-configuration";
    };

    #neovim-config = {
    # url = "git+file:/mnt/c/Users/manue/Documents/GitHub/neovim-configuration";
    #};

    distro-grub-themes = {
      url = "github:AdisonCavani/distro-grub-themes";
    };

    arion = {
      url = "github:hercules-ci/arion";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixcord = {
      url = "github:kaylorben/nixcord";
    };

    nix-jetbrains-plugins = {
      url = "github:PhilippHeuer/nix-jetbrains-plugins";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixos-wsl,
    nixos-generators,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = ["x86_64-linux"];
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

      deadServer = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs vars systems;};
        modules = [
          ./hosts/deadServer/config.nix
        ];
      };

      # build with nix build .#nixosConfigurations.deadPi.config.system.build.sdImage
      deadPi = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix"
          ./hosts/deadPi

          # extra config for sdImage generator
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
  };
}

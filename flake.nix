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
    # Nixkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
    };

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware.url = "github:nixos/nixos-hardware";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprpanel = {
      url = "github:jas-singhfsu/hyprpanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix/release-24.11";

    #textfox.url = "github:adriankarlen/textfox";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvix.url = "github:niksingh710/nvix";

    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
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
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${vars.username} = import ./hosts/deadConvertible/home.nix;
            nixpkgs.overlays = [self.overlays.unstable-packages];
          }
        ];
      };

      deadTest = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs vars;};
        modules = [
          ./hosts/deadTest/config.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${vars.username} = import ./hosts/deadTest/home.nix;
            nixpkgs.overlays = [self.overlays.unstable-packages];
          }
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
    };

    # home-manager switch --flake .#deadmade@<host>
    homeConfigurations = {
      "${vars.username}@deadWsl" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs vars;};
        modules = [
          ./hosts/deadWsl/home.nix
        ];
      };
      "${vars.username}@deadPc" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs vars;};
        modules = [
          ./hosts/deadPc/home.nix
        ];
      };
    };

    # Generate Iso -> Currently not really working. Need to look into what the best way is to do this
    packages.x86_64-linux = {
      deadPcIso = nixos-generators.nixosGenerate {
        specialArgs = {inherit inputs outputs vars;};
        system = "x86_64-linux";
        modules = [
          ./hosts/deadPc/config.nix
        ];
        format = "install-iso";
      };
    };
  };
}

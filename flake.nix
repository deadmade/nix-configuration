{
  description = "Deadmades's NixOS great config";

  inputs = {
    # Nixkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware.url = "github:nixos/nixos-hardware";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    hyprpanel = {
      url = "github:jas-singhfsu/hyprpanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #textfox.url = "github:adriankarlen/textfox";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #nvix.url = "github:niksingh710/nvix";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixos-wsl,
    home-manager,
    ...
  } @ inputs: let
    systems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    var = import ./variables.nix;
    homeManagerModules = import ./modules/home-manager;
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

    nixosConfigurations = {
      deadConvertible = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs homeManagerModules var;};
        modules = [
          ./hosts/deadConvertible/config.nix
          #inputs.stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${var.username} = import ./hosts/deadConvertible/home.nix;
            nixpkgs.overlays = [self.overlays.unstable-packages];
          }
        ];
      };
      deadTest = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs self var;};
        modules = [
          ./hosts/deadTest/config.nix
          #inputs.stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${var.username} = import ./hosts/deadTest/home.nix;
            nixpkgs.overlays = [self.overlays.unstable-packages];
          }
        ];
      };
      deadPc = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs self var;};
        modules = [
          ./hosts/deadPc/config.nix
          #inputs.stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = {inherit inputs;};
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${var.username} = import ./modules/home-manager/home-manager.nix;
            nixpkgs.overlays = [self.overlays.unstable-packages];
          }
        ];
      };
    };
  };
}

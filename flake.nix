{
  description = "Deadmades's NixOS great config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #hardware.url = "github:nixos/nixos-hardware";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
  };

  outputs =
    { self
    , nixpkgs
    , home-manager
    , ...
    } @ inputs:
    let
        inherit (self) outputs;
        systems = [
            "x86_64-linux"
        ];
        forAllSystems = nixpkgs.lib.genAttrs systems;
        username = (import ./variables.nix).username;
        nixosModules = import ./modules/nixos/default.nix;
    in
    {

      # Formatter for your nix files, available through 'nix fmt'
      # Other options beside 'alejandra' include 'nixpkgs-fmt'
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
    
      # Your custom packages and modifications, exported as overlays
      #overlays = import ./overlays { inherit inputs; };

      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs


      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      #homeManagerModules = import ./modules/home-manager;

      nixosConfigurations = {
        # deadConvertible = nixpkgs.lib.nixosSystem {
        #   specialArgs = { inherit inputs outputs username; };
        #   modules = [
        #     nixosModules
        #     ./hosts/deadConvertible/config.nix
        #     inputs.stylix.nixosModules.stylix
        #     home-manager.nixosModules.home-manager
        #     {
        #       home-manager.useGlobalPkgs = true;
        #       home-manager.useUserPackages = true;
        #       home-manager.users.${username} = import ./hosts/deadConvertible/home.nix;
        #     }
        #   ];
        # };
        deadTest = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs username; };
          modules = [
            nixosModules
            ./hosts/deadTest/config.nix
          ];
        };
      };
    };

}
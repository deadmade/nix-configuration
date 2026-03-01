{
  inputs,
  vars,
  systems,
  hostDefinitions,
  ...
}: let
  lib = inputs.nixpkgs.lib;
  projectOutputs = {
    overlays = import ../../overlays {inherit inputs;};
    nixosModules = import ../../modules/nixos;
    homeManagerModules = import ../../modules/home-manager;
    nixosProfiles = import ../../profiles/nixos;
    homeManagerProfiles = import ../../profiles/home-manager;
  };
  homeHosts = lib.filterAttrs (_: hostConfig: hostConfig.enableHome or false) hostDefinitions;
  mkHome = _hostName: hostConfig:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${hostConfig.system};
      extraSpecialArgs = {
        inherit inputs vars systems;
        outputs = projectOutputs;
      };
      modules = [
        hostConfig.homeModule
      ];
    };
in {
  flake.homeConfigurations =
    lib.mapAttrs' (
      hostName: hostConfig:
        lib.nameValuePair "${vars.username}@${hostName}" (mkHome hostName hostConfig)
    )
    homeHosts;
}

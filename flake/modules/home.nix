{
  inputs,
  vars,
  systems,
  hostDefinitions,
  projectOutputs,
  ...
}: let
  lib = inputs.nixpkgs.lib;
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

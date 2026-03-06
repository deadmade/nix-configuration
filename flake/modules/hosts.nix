{
  inputs,
  vars,
  systems,
  hostDefinitions,
  projectOutputs,
  ...
}: let
  lib = inputs.nixpkgs.lib;
  mkHost = _hostName: hostConfig:
    lib.nixosSystem {
      system = hostConfig.system;
      specialArgs = {
        inherit inputs vars systems;
        outputs = projectOutputs;
      };
      modules =
        (lib.optionals (hostConfig.useSdImageInstaller or false) [
          "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix"
        ])
        ++ hostConfig.nixosModules
        ++ (hostConfig.extraNixosModules or []);
    };
in {
  flake.nixosConfigurations = lib.mapAttrs mkHost hostDefinitions;
}

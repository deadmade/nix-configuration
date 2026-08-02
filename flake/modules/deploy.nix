{
  inputs,
  hostDefinitions,
  config,
  ...
}: let
  lib = inputs.nixpkgs.lib;

  # hosts/<name>/deploy.nix is a plain attrset, not a NixOS module: the host
  # directory is imported as ./<name>, which resolves to default.nix only.
  deployFileFor = name: ../../hosts + "/${name}/deploy.nix";

  deployHosts = lib.filterAttrs (name: _: builtins.pathExists (deployFileFor name)) hostDefinitions;

  mkNode = name: hostConfig:
    lib.recursiveUpdate (import (deployFileFor name)) {
      profiles.system.path =
        inputs.deploy-rs.lib.${hostConfig.system}.activate.nixos
        config.flake.nixosConfigurations.${name};
    };
in {
  flake.deploy.nodes = lib.mapAttrs mkNode deployHosts;

  perSystem = {system, ...}: {
    apps.deploy = {
      type = "app";
      program = lib.getExe inputs.deploy-rs.packages.${system}.default;
    };
  };
}

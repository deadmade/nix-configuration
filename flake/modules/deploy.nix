{
  inputs,
  hostDefinitions,
  config,
  ...
}: let
  lib = inputs.nixpkgs.lib;

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
      meta.description = "Deploy NixOS hosts with deploy-rs";
    };
  };
}

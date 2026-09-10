{inputs, ...}: let
  registry = import ../lib/registry.nix;
  projectOutputs = {
    overlays = import ../../overlays {inherit inputs;};
    nixosModules = registry ../../modules/nixos;
    homeManagerModules = registry ../../modules/home-manager;
  };
in {
  _module.args.projectOutputs = projectOutputs;
  flake = projectOutputs;
}

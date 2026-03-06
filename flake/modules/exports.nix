{inputs, ...}: let
  projectOutputs = {
    overlays = import ../../overlays {inherit inputs;};
    nixosModules = import ../../modules/nixos;
    homeManagerModules = import ../../modules/home-manager;
    nixosProfiles = import ../../profiles/nixos;
    homeManagerProfiles = import ../../profiles/home-manager;
  };
in {
  _module.args.projectOutputs = projectOutputs;
  flake = projectOutputs;
}

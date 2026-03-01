{inputs, ...}: {
  flake.overlays = import ../../overlays {inherit inputs;};
  flake.nixosModules = import ../../modules/nixos;
  flake.homeManagerModules = import ../../modules/home-manager;
  flake.nixosProfiles = import ../../profiles/nixos;
  flake.homeManagerProfiles = import ../../profiles/home-manager;
}

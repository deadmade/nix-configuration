{
  vm = import ./vm.nix;
  docker = import ./docker.nix;
  podman = import ./podman.nix;
  vmware = import ./vmware.nix;
}

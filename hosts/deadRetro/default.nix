# deadRetro: a NixOS 14.12 KDE 4 desktop running as a qemu VM.
#
# Unlike the other hosts this is not a `nixosConfiguration` -- it is evaluated
# with the 14.12 nixpkgs supplied by nixpkgs-multiverse and exposed as the
# `deadRetro` flake app (see flake/modules/per-system.nix), so it is not listed
# in hosts/hosts.nix.
{
  inputs,
  system,
  pkgs,
}: let
  pkgs14 = inputs.multiverse.multiverse.${system}.at "14.12";

  vm =
    (import "${pkgs14.path}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        "${pkgs14.path}/nixos/modules/virtualisation/qemu-vm.nix"
        ./config.nix
      ];
    })
    .config
    .system
    .build
    .vm;
in
  pkgs.writeShellScript "run-deadRetro" ''
    # The host's LOCALE_ARCHIVE is built by a much newer glibc than the one in
    # the 14.12 closure, so the VM runtime has to fall back to the C locale.
    export LC_ALL=C
    unset LOCALE_ARCHIVE

    # virtualisation.diskImage lives here; readlink -f in the generated start
    # script needs the parent directory to exist.
    mkdir -p "$HOME/.local/share/deadRetro"

    exec ${vm}/bin/run-nixos-vm "$@"
  ''

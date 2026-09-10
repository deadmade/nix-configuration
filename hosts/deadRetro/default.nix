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

  # Run the VM under the host's qemu rather than the qemu 2.0.0 that ships in
  # the 14.12 closure. The guest's entire /nix/store is a 9p mount, and eleven
  # years of 9p and virtio work is the single biggest speedup available here.
  # It also unlocks `-cpu host` and per-device options like VGA's vgamem_mb.
  #
  # The old start script's `-net ...,vlan=0` syntax was removed in qemu 3.0, but
  # config.nix replaces networkingOptions with `-net none` anyway.
  useHostQemu = {
    nixpkgs.config.packageOverrides = _: {
      qemu_kvm = pkgs.qemu_kvm;
    };
  };

  vm =
    (import "${pkgs14.path}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        "${pkgs14.path}/nixos/modules/virtualisation/qemu-vm.nix"
        ./config.nix
        useHostQemu
      ];
    })
    .config
    .system
    .build
    .vm;
in
  pkgs.writeShellScript "run-deadRetro" ''
    # config.nix passes -accel kvm -cpu host, neither of which has a fallback.
    if [ ! -e /dev/kvm ]; then
      echo "deadRetro: /dev/kvm is not available -- this VM needs KVM." >&2
      exit 1
    fi

    # The host's LOCALE_ARCHIVE is built by a much newer glibc than the one in
    # the 14.12 closure, so the VM runtime has to fall back to the C locale.
    export LC_ALL=C
    unset LOCALE_ARCHIVE

    # virtualisation.diskImage lives here; readlink -f in the generated start
    # script needs the parent directory to exist.
    mkdir -p "$HOME/.local/share/deadRetro"

    exec ${vm}/bin/run-nixos-vm "$@"
  ''

{
  inputs,
  system,
  pkgs,
}: let
  pkgs14 = inputs.multiverse.multiverse.${system}.at "14.12";

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
    if [ ! -e /dev/kvm ]; then
      echo "deadRetro: /dev/kvm is not available -- this VM needs KVM." >&2
      exit 1
    fi

    export LC_ALL=C
    unset LOCALE_ARCHIVE

    mkdir -p "$HOME/.local/share/deadRetro"

    exec ${vm}/bin/run-nixos-vm "$@"
  ''

{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    pre-commit-check = inputs.git-hooks.lib.${system}.run {
      src = ../..;
      hooks = {
        alejandra.enable = true;
        flake-checker.enable = false;
        check-merge-conflicts.enable = true;
        convco.enable = true;
        check-added-large-files.enable = true;
        end-of-file-fixer.enable = true;
        trufflehog.enable = true;
      };
    };
  in {
    formatter = pkgs.alejandra;

    # Vendored packages, also exposed so `nix build .#helium` works and CI can
    # verify the build after the auto-update bumps its version/hashes.
    packages.helium = pkgs.callPackage ../../pkgs/helium {};

    # claude-science is unfree, and perSystem's shared `pkgs` is the plain
    # flake-parts default. Use a locally-configured nixpkgs so `nix build
    # .#claude-science` works without relaxing allowUnfree flake-wide.
    packages.claude-science =
      (import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      })
      .callPackage
      ../../pkgs/claude-science {};

    devShells.default = pkgs.mkShell {
      inherit (pre-commit-check) shellHook;
      buildInputs = pre-commit-check.enabledPackages;
      packages = with pkgs; [
        lazygit
        ripgrep
      ];
    };

    apps.deadRetro = {
      type = "app";
      program = let
        pkgs14 = inputs.multiverse.multiverse.${system}.at "14.12";
        retroVM = import "${pkgs14.path}/nixos/lib/eval-config.nix" {
          inherit system;
          modules = [
            "${pkgs14.path}/nixos/modules/virtualisation/qemu-vm.nix"
            ({pkgs, ...}: {
              services.xserver = {
                enable = true;
                displayManager.kdm.enable = true;
                desktopManager.kde4.enable = true;

                # Set a specific resolution
                resolutions = [
                  {
                    x = 1920;
                    y = 1080;
                  }
                ];

                # If you want to change the keyboard layout from US:
                layout = "de";
              };

              environment.systemPackages = with pkgs; [
                kde4.kdegraphics
                kde4.kdemultimedia
                kde4.kdenetwork # Includes Kopete
                kde4.kdegames # Classic KDE games
                kde4.kdetoys # AMOR, KTeaTime
                kde4.yakuake # Iconic drop-down terminal
                kde4.konversation # KDE IRC client
                audacious
                clementine # Amarok fork! peak 2014 music
                pidgin
                xchat # Classic GTK IRC
                abiword # Lightweight word processor
                gnumeric # Spreadsheet
                conky
                vlc
                firefox
              ];

              users.extraUsers.retro = {
                isNormalUser = true;
                password = "retro";
              };

              virtualisation.memorySize = 4096;
              virtualisation.qemu.options = ["-vga qxl" "-smp 2"];
            })
          ];
        };
        wrapper = pkgs.writeShellScript "run-deadRetro" ''
          export LC_ALL=C
          unset LOCALE_ARCHIVE
          exec ${retroVM.config.system.build.vm}/bin/run-nixos-vm "$@"
        '';
      in "${wrapper}";
    };
  };
}

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
        check-added-large-files = {
          enable = true;
          # 500kB, the upstream default, rejects most of wallpapers/ -- and the
          # kaneki-abyss video loop in wallpapers/video/ is 13MB. Raised rather
          # than bypassed with --no-verify so adding a wallpaper stays a normal
          # commit.
          args = ["--maxkb=20000"];
        };
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

    # deadRetro is a NixOS 14.12 KDE 4 VM rather than a nixosConfiguration, so
    # it lives in hosts/deadRetro/ but is exposed as an app instead of via
    # hosts/hosts.nix. Run it with `nix run .#deadRetro`.
    apps.deadRetro = {
      type = "app";
      program = "${import ../../hosts/deadRetro {inherit inputs system pkgs;}}";
    };
  };
}

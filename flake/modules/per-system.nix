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
        cachix
        vulnix
        ripgrep
      ];
    };
  };
}

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

          args = ["--maxkb=20000"];
        };
        end-of-file-fixer.enable = true;
        trufflehog.enable = true;
      };
    };

    helium-update = pkgs.writeShellScriptBin "helium-update" ''
      exec "$(${pkgs.git}/bin/git rev-parse --show-toplevel)/pkgs/helium/update.sh" "$@"
    '';
  in {
    formatter = pkgs.alejandra;

    packages.helium = pkgs.callPackage ../../pkgs/helium {};

    packages.claude-science =
      (import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      })
      .callPackage
      ../../pkgs/claude-science {};

    devShells.default = pkgs.mkShell {
      shellHook =
        pre-commit-check.shellHook
        + ''
          "$(${pkgs.git}/bin/git rev-parse --show-toplevel)/pkgs/helium/check.sh" || true
        '';
      buildInputs = pre-commit-check.enabledPackages;
      packages = with pkgs; [
        lazygit
        ripgrep
        curl
        helium-update
      ];
    };

    apps.deadRetro = {
      type = "app";
      program = "${import ../../hosts/deadRetro {inherit inputs system pkgs;}}";
    };
  };
}

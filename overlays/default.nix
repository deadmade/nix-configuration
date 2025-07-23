# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  #additions = final: _prev: import ../pkgs {pkgs = final;};

  # Third party overlays
  # nh = inputs.nh.overlays.default;

  # For every flake input, aliases 'pkgs.inputs.${flake}' to
  # 'inputs.${flake}.packages.${pkgs.system}' or
  # 'inputs.${flake}.legacyPackages.${pkgs.system}'
  flake-inputs = final: _: {
    inputs =
      builtins.mapAttrs
      (
        _: flake: let
          legacyPackages = (flake.legacyPackages or {}).${final.system} or {};
          packages = (flake.packages or {}).${final.system} or {};
        in
          if legacyPackages != {}
          then legacyPackages
          else packages
      )
      inputs;
  };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # opencode = prev.opencode.overrideAttrs {
    #  #§" opencode-node-modules-hash."x86_64-linux" = "sha256-VB7bikVFy8w82M6AkYXjsHx34CNHAGMgY69KISOokE4=";

    #   version = "0.3.22";
    #   src = prev.fetchFromGitHub {
    #     owner = "sst";
    #     repo = "opencode";
    #     tag = "v${prev.opencode.version}";
    #     hash = "sha256-yT6uaTEKYb/+A1WhP6AQW0hWMnmS9vlfLn1E57cnzn0=";
    #   };

    #   vendorHash = "sha256-G1vM8wxTTPpB1Oaxz2YI8AkirwG54A9i6Uq5e92ucyY=";
    #   outputHash = "sha256-VB7bikVFy8w82M6AkYXjsHx34CNHAGMgY69KISOokE4=";
    # };

    # hyprlandPlugins.hyprsplit = prev.hyprlandPlugins.hyprsplit.overrideAttrs {
    #   version = "0.50.0";
    #   src = prev.fetchFromGitHub {
    #     owner = "shezdy";
    #     repo = "hyprsplit";
    #     tag = "v0.50.1";
    #     hash = "sha256-D0zfdUJXBRnNMmv/5qW+X4FJJ3/+t7yQmwJFkBuEgck=";
    #   };

    #};
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}

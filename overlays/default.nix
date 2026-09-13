{inputs, ...}: {
  additions = final: _prev: import ../pkgs {pkgs = final;};

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

  modifications = _final: prev: {
    logiops = prev.logiops.overrideAttrs (old: {
      patches =
        (old.patches or [])
        ++ [
          (prev.fetchpatch {
            url = "https://github.com/PixlOne/logiops/commit/e15799553f97c1b8bab5d9b22b58453513b56217.patch";
            hash = "sha256-4ME84R4F48/CJNcfLEJxhArrVgomnjMW11Vw7xb7Ffg=";
          })
        ];
    });
  };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };
}

# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {pkgs = final;};

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

    # nix-ld falls back to a compile-time default loader path when NIX_LD is
    # absent from the environment, and upstream bakes in
    # /run/current-system/sw/share/nix-ld/lib/ld.so. That path is unreachable
    # inside a bubblewrap sandbox, because sandboxes typically bind /nix but
    # not /run — so nix-ld aborts at main.rs:187 with
    # `called Result::unwrap() on an Err value: Posix(2)` (ENOENT on the
    # loader). claude-science hits this for every bundled conda MCP env: its
    # sandbox env allowlist is a hardcoded ["HOME","LOGNAME","PATH","SHELL",
    # "TERM","USER"], so NIX_LD cannot be passed in from outside.
    #
    # Pointing the fallback at a /nix/store glibc puts it inside a prefix
    # sandboxes do bind. This only changes behaviour when NIX_LD is unset —
    # which, outside a sandbox, it never is, since the nix-ld NixOS module
    # exports it system-wide. Verified A/B: patched loader runs a sandboxed
    # non-Nix binary with NIX_LD unset, stock loader panics.
    #
    # Note DEFAULT_NIX_LD_LIBRARY_PATH is a plain constant in nix-ld's source
    # with no option_env! escape hatch, so the library-search fallback still
    # points at /run. That is fine for binaries needing only the loader's own
    # glibc; anything needing more system libs inside a sandbox will still
    # fail. See pkgs/claude-science.
    # final.glibc, not prev.glibc: `prev` here predates the rest of the overlay
    # chain and yields a *different* glibc than the system actually uses, which
    # would pull a second, redundant glibc into the closure.
    nix-ld = prev.nix-ld.overrideAttrs (_: {
      DEFAULT_NIX_LD = "${final.glibc}/lib/ld-linux-x86-64.so.2";
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };
}

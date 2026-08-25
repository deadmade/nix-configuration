# Remove nix-mineral, add NixSecAuditor

**Date:** 2026-08-01
**Status:** Approved (scope: all NixOS hosts)

## Goal

Drop the nix-mineral hardening module (unused — `enable = false` on deadPc, and it
historically broke things) and replace the "security posture" role with
[NixSecAuditor](https://github.com/unnamed-systems/nixsecauditor), an eval-time
static auditor that warns about insecure NixOS configuration instead of changing it.

## Changes

### Remove nix-mineral

- `flake.nix`: delete the `nix-mineral` input.
- `hosts/deadPc/config.nix`: delete the `inputs.nix-mineral.nixosModules.nix-mineral`
  import and the whole `nix-mineral = { ... }` block (it was disabled anyway).
- `hosts/deadPc/config.nix`: drop the stale `alsa.support32Bit = lib.mkForce false`
  override — it existed only for the hardened kernel's `ia32_emulation=0`; with
  nix-mineral gone, 32-bit audio (Steam/Proton) returns via `desktop/base.nix`.
- `CLAUDE.md`: remove the nix-mineral rebuild note (`nixos-rebuild boot` guidance).
- `flake.lock`: regenerated via `nix flake lock`.

### Add NixSecAuditor (all NixOS hosts)

- `flake.nix`: add input `nixsecauditor` (`github:unnamed-systems/nixsecauditor`,
  `nixpkgs` follows ours).
- New module `modules/nixos/core/nixsecauditor.nix`: imports
  `inputs.nixsecauditor.nixosModules.default` and sets
  `security.nixsecauditor.enable = true`.
- Register it in `modules/nixos/core/default.nix`; the `core` profile imports the
  whole core domain via `builtins.attrValues`, so every host gets it automatically.

Eval-time reporting stays at its default (enabled): `warn` findings show as
evaluation warnings on every rebuild; `throw` findings would fail evaluation.
JSON/Markdown report packages
(`security.nixsecauditor.report.outPackages.{json,markdown}`) remain available for
on-demand audits. Individual rules can be muted later via
`security.nixsecauditor.rules.<name>.enable = false`.

## Verification

1. `nix build .#nixosConfigurations.deadPc.config.system.build.toplevel --dry-run`
   evaluates successfully and surfaces any auditor warnings.
2. Build the Markdown report for deadPc and inspect the findings.
3. Spot-check a second host (e.g. deadServer) still evaluates.

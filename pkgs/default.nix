# Custom packages, exposed through the `additions` overlay (see
# overlays/default.nix) so they're available as `pkgs.<name>`.
{pkgs}: {
  helium = pkgs.callPackage ./helium {};
}

# Helium browser. Vendored in ../../../pkgs/helium and exposed as pkgs.helium
# via the `additions` overlay. Flags are baked into the wrapper.
{pkgs, ...}: {
  home.packages = [
    pkgs.helium
  ];
}

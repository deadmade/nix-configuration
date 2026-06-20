# Helium browser. Vendored in ../../../pkgs/helium and exposed as pkgs.helium
# via the `additions` overlay. Flags are baked into the wrapper.
{pkgs, ...}: {
  home.packages = [
    (pkgs.helium.override {
      flags = [
        "--enable-features=WebUIDarkMode"
        "--force-dark-mode"
        "--password-store=basic" # don't leak passwords into the keyring
      ];
    })
  ];
}

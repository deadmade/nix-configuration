{
  pkgs,
  lib,
  ...
}: {
  programs.chromium = {
    enable = true;
    package = pkgs.unstable.brave;

    # Map extensions to their Chrome Web Store IDs
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb"
      "ghmbeldphafepmbegfdlkpapadhbakde"
      "eimadpbcbfnmbkopoojfekhnkhdbieeh"
    ];

    # Command line flags for settings that don't have direct Policy equivalents
    commandLineArgs = [
      "--disable-features=WebRtcHideLocalIpsWithMdns" # Privacy improvement
      "--disable-reading-from-canvas" # Resist Fingerprinting equivalent
      "--no-default-browser-check"
      "--disable-breakpad" # Disable crash reporting
      "--ozone-platform=wayland"
    ];
  };
}

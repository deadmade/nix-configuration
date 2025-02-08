{
  inputs,
  pkgs,
  ...
}: {
  programs.floorp = {
    enable = true;

    profiles.Default = {
      extensions = with inputs.firefox-addons.packages."x86_64-linux"; [
        ublock-origin
        darkreader
        tabliss
        consent-o-matic
        gesturefy
        vimium
      ];

      settings = {
      };
    };
  };
}

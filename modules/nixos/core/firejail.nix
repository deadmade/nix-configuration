{pkgs, ...}: {
  programs.firejail = {
    enable = true;
    wrappedBinaries = {
      curl = {
        executable = "${pkgs.curl}/bin/curl";
      };

      git = {
        executable = "${pkgs.git}/bin/git";
      };

      btop = {
        executable = "${pkgs.btop}/bin/btop";
      };

      kitty = {
        executable = "${pkgs.kitty}/bin/kitty";
      };

      wl-clipboard = {
        executable = "${pkgs.wl-clipboard}/bin/wl-clipboard";
      };
    };
  };
}

{pkgs, ...}: {
  programs.firejail = {
    enable = true;
    wrappedBinaries = {
      freetube = {
        executable = "${pkgs.unstable.freetube}/bin/freetube";
        profile = "${pkgs.firejail}/etc/firejail/freetube.profile";
      };
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

      ranger = {
        executable = "${pkgs.ranger}/bin/ranger";
      };

      cachix = {
        executable = "${pkgs.cachix}/bin/cachix";
      };
    };
  };
}

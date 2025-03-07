{pkgs, ...}: {
  programs.firejail = {
    enable = true;
    wrappedBinaries = {
      freetube = {
        executable = "${pkgs.unstable.freetube}/bin/freetube";
        profile = "${pkgs.firejail}/etc/firejail/freetube.profile";
      };

      onlyoffice-desktopeditors = {
        executable = "${pkgs.onlyoffice-desktopeditors}/bin/desktopeditors";
        #profile = "${pkgs.firejail}/etc/firejail/onlyoffice.profile";
      };

      protonmail-desktop = {
        executable = "${pkgs.unstable.protonmail-desktop}/bin/protonmail";
       # profile = "${pkgs.firejail}/etc/firejail/protonmail-desktop.profile";
      };

      okular = {
        executable = "${pkgs.unstable.kdePackages.okular}/bin/okular";
        profile = "${pkgs.firejail}/etc/firejail/okular.profile";
      };

      steam = {
        executable = "${pkgs.steam}/bin/steam";
        profile = "${pkgs.firejail}/etc/firejail/steam.profile";
      };
    };
  };
}

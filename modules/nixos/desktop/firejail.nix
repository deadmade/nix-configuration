{pkgs, ...}: {
  programs.firejail = {
    enable = true;
    wrappedBinaries = {
      steam = {
        executable = "${pkgs.steam}/bin/steam";
        profile = "${pkgs.firejail}/etc/firejail/steam.profile";
      };

      protonmail-desktop = {
        executable = "${pkgs.unstable.protonmail-desktop}/bin/protonmail-desktop";
        profile = "${pkgs.firejail}/etc/firejail/electron.profile";
        extraArgs = ["--private-tmp"];
      };

      thunderbird = {
        executable = "${pkgs.unstable.thunderbird}/bin/thunderbird";
        profile = "${pkgs.firejail}/etc/firejail/thunderbird.profile";
      };

      okular = {
        executable = "${pkgs.unstable.kdePackages.okular}/bin/okular";
        profile = "${pkgs.firejail}/etc/firejail/okular.profile";
      };

      libreoffice = {
        executable = "${pkgs.unstable.libreoffice-fresh}/bin/libreoffice";
        profile = "${pkgs.firejail}/etc/firejail/libreoffice.profile";
      };

      opencode = {
        executable = "${pkgs.unstable.opencode}/bin/opencode";
        profile = "${pkgs.firejail}/etc/firejail/code.profile";
        extraArgs = ["--ignore=noroot"];
      };

      # thunar = {
      #   executable = "${pkgs.xfce.thunar}/bin/thunar";
      #   profile = "${pkgs.firejail}/etc/firejail/thunar.profile";
      #   extraArgs = ["--ignore=noroot"];
      # };

      spotify-player = {
        executable = "${pkgs.unstable.spotify-player}/bin/spotify_player";
        profile = "${pkgs.firejail}/etc/firejail/spotify.profile";
      };

      nwg-displays = {
        executable = "${pkgs.unstable.nwg-displays}/bin/nwg-displays";
        profile = "${pkgs.firejail}/etc/firejail/default.profile";
      };

      presenterm = {
        executable = "${pkgs.unstable.presenterm}/bin/presenterm";
        profile = "${pkgs.firejail}/etc/firejail/default.profile";
      };
    };
  };
}

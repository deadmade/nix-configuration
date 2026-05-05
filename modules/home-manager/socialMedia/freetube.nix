{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.freetube-nix.homeManagerModules.default
  ];

  programs.freetube = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "freetube-wrapped";
      paths = [pkgs.freetube];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/freetube \
          --add-flags "--disable-gpu"
      '';
    };

    settings = {
      baseTheme = "catppuccinMocha";
      checkForUpdates = false;
      defaultQuality = "1080";
      allowDashAv1Formats = true;
      backendFallback = true;
      saveHistory = false;
      sponsorBlockSponsor = "skip";
      sponsorBlockSelfPromo = "skip";
    };

    profiles = [
      {
        _id = "allChannels";
        name = "All Channels";
        bgColor = "#BD93F9";
        textColor = "#000000";
        subscriptions = [
          # Add subscriptions like:
          # { id = "UCxxxxxxxxxxxxxxxxxxxxxx"; name = "Channel Name"; thumbnail = ""; }
        ];
      }
    ];
  };
}

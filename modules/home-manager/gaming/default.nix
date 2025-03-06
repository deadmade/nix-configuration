{pkgs, ...}: {
  home.packages = with pkgs; [
    heroic
    (lutris.override {
      extraLibraries = pkgs: [
        wine
        wineWowPackages.stable
      ];
    })

    gamescope
    gamemode
  ];
}

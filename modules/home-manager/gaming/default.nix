{pkgs, ...}: {
  home.packages = with pkgs; [
    heroic
    (lutris.override {
      extraLibraries = _pkgs: [
        wine
        wineWowPackages.stable
      ];
    })

    gamescope
    gamemode
  ];
}

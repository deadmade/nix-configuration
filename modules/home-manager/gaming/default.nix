{pkgs, ...}: {
  home.packages = with pkgs.unstable; [
    heroic

    (lutris.override {
      extraPkgs = _pkgs: [
        wineWowPackages.stable
        winetricks
      ];
    })

    wineWowPackages.stable
    winetricks

    gamescope
    gamemode
  ];
}

{pkgs, ...}: {
  home.packages = with pkgs.unstable; [
    heroic
    (lutris.override {
      extraLibraries = _pkgs: [
        wine
        wineWow64Packages.stable
      ];
    })

    gamescope
    gamemode
  ];
}

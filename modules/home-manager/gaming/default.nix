{pkgs, ...}: {
  home.packages = with pkgs.unstable; [
    heroic

    # Lutris ships FHS-wrapped: extraPkgs goes into targetPkgs (executables),
    # extraLibraries into multiPkgs (32-bit libs). Wine belongs in the former.
    # wineWowPackages (classic multilib) over wineWow64Packages: new-mode WoW64
    # is still unreliable for old 32-bit D3D9 titles.
    (lutris.override {
      extraPkgs = _pkgs: [
        wineWowPackages.stable
        winetricks
      ];
    })

    # Also outside Lutris, for driving a bare prefix with winecfg/winetricks.
    wineWowPackages.stable
    winetricks

    gamescope
    gamemode
  ];
}

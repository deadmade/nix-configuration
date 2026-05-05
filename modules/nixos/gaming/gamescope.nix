{pkgs, ...}: {
  programs.gamescope = {
    enable = true;
    package = pkgs.unstable.gamescope;
    capSysNice = true;
    args = [
      "--rt"
      "--expose-wayland"
    ];
  };
}

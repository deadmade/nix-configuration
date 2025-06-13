{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    (python3.withPackages (python-pkgs:
      with python-pkgs; [
        pygments
      ]))
    pkgs.unstable.inkscape
    pkgs.unstable.texlive.combined.scheme-full
    pkgs.unstable.texlivePackages.texapi
    pkgs.unstable.texlivePackages.yax
  ];

  fonts.packages = with pkgs; [
    helvetica-neue-lt-std
  ];
}

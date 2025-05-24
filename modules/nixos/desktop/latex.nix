{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    (python3.withPackages (python-pkgs:
      with python-pkgs; [
        pygments
      ]))
    pkgs.unstable.inkscape
  ];

  fonts.packages = with pkgs; [
    helvetica-neue-lt-std
  ];
}

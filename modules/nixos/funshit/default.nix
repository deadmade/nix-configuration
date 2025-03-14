{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    cbonsai # cbonsai --seed <seed> --live
    asciiquarium # asciiquarium
    hollywood
    sl
    fortune
    cmatrix
    oneko
    bb
  ];
}

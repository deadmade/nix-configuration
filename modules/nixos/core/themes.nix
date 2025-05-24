{pkgs, ...}: {
  fonts.packages = with pkgs; [
    pkgs.nerd-fonts.jetbrains-mono
  ];
}

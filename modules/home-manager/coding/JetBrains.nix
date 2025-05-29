{
  config,
  pkgs,
  inputs,
  outputs,
  ...
}: {
    home.packages = with pkgs; [
    pkgs.unstable.jetbrains.rider
    pkgs.unstable.jetbrains.pycharm-professional
  ];


}
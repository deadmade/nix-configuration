{
  pkgs,
  vars,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    quickemu
  ];
}

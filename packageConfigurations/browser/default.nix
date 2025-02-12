{
  pkgs,
  outputs,
  ...
}: {
  imports = [
    #./firefox/firefox.nix
    ./floorp/floorp.nix
  ];
}

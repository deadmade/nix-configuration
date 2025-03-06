{
  pkgs,
  outputs,
  ...
}: {
  imports = [
    #./firefox/firefox.nix
    ./floorp/floorp.nix
    #./librewolf/librewolf.nix
  ];
}

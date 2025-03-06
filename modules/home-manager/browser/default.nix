{
  pkgs,
  outputs,
  ...
}: {
  firefox = import ./firefox/firefox.nix;
  floorp = import ./floorp/floorp.nix;
  librewolf = import ./librewolf/librewolf.nix;
}

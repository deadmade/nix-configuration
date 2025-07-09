{
  home = import ./homeConfig.nix;
  git = import ./git.nix;
  btop = import ./btop.nix;
  nixConfig = import ./nixConfig.nix;
  stylix = import ./stylix.nix;
  aliases = import ./aliases.nix;
}

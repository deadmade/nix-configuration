{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix =
    (import ../../../flake/lib/theme.nix {inherit pkgs;})
    // {
      enable = true;
      autoEnable = true;

      targets = {
        grub.enable = false;

        qt.enable = false;
      };
    };
}

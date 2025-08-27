{
  pkgs,
  lib,
  ...
}: {
  programs = {
    direnv = {
      enable = true;
      enableZshIntegration = true;
      package = pkgs.unstable.direnv;
      nix-direnv.enable = true;
      nix-direnv.package = pkgs.unstable.nix-direnv;
    };

  };

  services.lorri.enable = true;
}

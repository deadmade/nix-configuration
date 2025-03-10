{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    inputs.arion.nixosModules.arion
  ];

  environment.systemPackages = with pkgs; [arion];

  virtualisation.arion.backend = "docker";
}

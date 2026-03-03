{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs; [sops];

  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops.defaultSopsFile = ../../secrets/deadServer.yaml;
  sops.defaultSopsFormat = "yaml";

  sops.age.keyFile = "/home/deadmade/.config/sops/age/keys.txt";
}

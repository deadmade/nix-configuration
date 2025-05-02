{ pkgs, inputs, config, vars, ... }:
{
  environment.systemPackages = with pkgs; [ sops ];

  imports =
    [
      inputs.sops-nix.nixosModules.sops
    ];

  sops.defaultSopsFile = ../../secrets/deadWsl.yaml;
  sops.defaultSopsFormat = "yaml";
  
  sops.age.keyFile = "/home/deadmade/.config/sops/age/keys.txt";
}
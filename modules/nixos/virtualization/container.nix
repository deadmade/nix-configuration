{
  pkgs,
  vars,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    lazydocker
  ];

  virtualisation = lib.mkForce {
    docker = {
      enable = true;
    };
    containers.enable = true;
  };
  users.users.${vars.username} = {
    extraGroups = ["docker"];
  };
}

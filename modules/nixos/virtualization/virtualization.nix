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
      enable = false;
    };

    podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  users.users.${vars.username} = {
    extraGroups = ["podman"];
  };
}

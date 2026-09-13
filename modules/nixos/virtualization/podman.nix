{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lazydocker
    docker-compose
  ];

  virtualisation = {
    podman = {
      enable = true;

      dockerCompat = true;

      defaultNetwork.settings.dns_enabled = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    containers.enable = true;
  };

  environment.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
}

{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lazydocker
    docker-compose
  ];

  virtualisation = {
    podman = {
      enable = true;
      # Symlinks `docker` -> `podman`, so `docker compose up` becomes
      # `podman compose up` and delegates to the docker-compose provider.
      dockerCompat = true;
      # Docker enables inter-container DNS implicitly; podman does not.
      defaultNetwork.settings.dns_enabled = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    containers.enable = true;
  };

  # Point Docker-API clients at the rootless socket instead of
  # /var/run/docker.sock. Verified to expand in Task 3.
  environment.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
}

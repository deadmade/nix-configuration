{
  virtualisation = {
    docker.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = !dockerEnabled;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}

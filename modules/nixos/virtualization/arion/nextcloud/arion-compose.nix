{
  project.name = "nextcloud";

  networks.dmz = {
    name = "dmz";
    external = true;
  };

  networks.transport = {};

  services = {
    nextcloud.service = {
      image = "nextcloud:30.0.4";
      container_name = "nextcloud";
      useHostStore = true;
      volumes = [
        "/storage/dataset/docker/nextcloud/nextcloud_data/data:/var/www/html/data"
        "/home/deadmade/.docker/nextcloud/nextcloud_data:/var/www/html"
      ];
      entrypoint = "/bin/bash -c 'apt update && apt install ffmpeg -y && /entrypoint.sh apache2-foreground'";
      restart = "unless-stopped";
      networks = [
        "dmz"
        "transport"
      ];
    };
  };
}

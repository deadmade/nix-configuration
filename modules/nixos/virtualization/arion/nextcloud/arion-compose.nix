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
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.nextcloud.entrypoints" = "websecure";
        "traefik.http.routers.nextcloud.rule" = "Host(`nextcloud.ghoscht.com`)";
        "traefik.docker.network" = "dmz";
        "traefik.http.routers.nextcloud.tls" = "true";
        "traefik.http.routers.nextcloud.tls.certresolver" = "letsencrypt";

        "pihole.custom-record" = "[[\"nextcloud.ghoscht.com\", \"ghoscht.com\"]]";
      };
      volumes = [
        "/storage/dataset/docker/nextcloud/nextcloud_data/data:/var/www/html/data"
        "/home/ghoscht/.docker/nextcloud/nextcloud_data:/var/www/html"
      ];
      entrypoint = "/bin/bash -c 'apt update && apt install ffmpeg -y && /entrypoint.sh apache2-foreground'";
      hostname = "nextcloud.ghoscht.com";
      environment = {
        REDIS_HOST = "nextcloud-redis";
        REDIS_PORT = 6379;
        TRUSTED_PROXIES = "172.27.0.9/24";
      };
      restart = "unless-stopped";
      networks = [
        "dmz"
        "transport"
      ];
    };
    nextcloud-db.service = {
      image = "mariadb:11.4.1-rc-jammy";
      env_file = [
        "/home/ghoscht/.docker/nextcloud/nextcloud.env"
      ];
      volumes = [
        "/home/ghoscht/.docker/nextcloud/nextcloud_db:/var/lib/mysql"
      ];
      restart = "unless-stopped";
      command = "--transaction-isolation=READ-COMMITTED --binlog-format=ROW";
      networks = [
        "transport"
      ];
    };
    nextcloud-redis.service = {
      image = "redis:alpine3.19";
      restart = "unless-stopped";
      networks = [
        "transport"
      ];
    };
  };
}

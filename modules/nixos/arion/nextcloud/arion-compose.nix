{
  project.name = "nextcloud";

  networks.dmz = {
    name = "dmz";
    external = true;
  };

  networks.transport = {};

  services = {
    nextcloud.service = {
      image = "nextcloud:31.0.6";
      container_name = "nextcloud";
      useHostStore = true;
      labels = {
        "traefik.enable" = "true";

        "traefik.http.routers.nextcloud-https.tls" = "true";
        "traefik.http.routers.nextcloud-https.tls.certresolver" = "cloudflare";
        "traefik.http.routers.nextcloud-https.entrypoints" = "websecure";
        "traefik.http.routers.nextcloud-https.rule" = "Host(`nextcloud.home.deadmade.de`)";

        "traefik.http.routers.nextcloud-https.tls.domains[0].main" = "home.deadmade.de";
        "traefik.http.routers.nextcloud-https.tls.domains[0].sans" = "*.home.deadmade.de";

        "traefik.http.middlewares.portainer-https-redirect.redirectscheme.scheme" = "https";
        "traefik.http.middlewares.sslheader.headers.customrequestheaders.X-Forwarded-Proto" = "https";
      };
      volumes = [
        "/storage/dataset/docker/nextcloud/nextcloud_data/data:/var/www/html/data"
        "/home/deadmade/.docker/nextcloud/nextcloud_data:/var/www/html"
      ];
      entrypoint = "/bin/bash -c 'apt update && apt install ffmpeg -y && /entrypoint.sh apache2-foreground'";
      hostname = "nextcloud.home.deadmade.de";
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
      image = "mariadb:lts-ubi";
      container_name = "nextcloud-db";
      env_file = [
        "/home/deadmade/.docker/nextcloud/nextcloud.env"
      ];
      labels = {
        "traefik.enable" = "false";
      };
      volumes = [
        "/home/deadmade/.docker/nextcloud/nextcloud_db:/var/lib/mysql"
      ];
      restart = "unless-stopped";
      command = "--transaction-isolation=READ-COMMITTED --binlog-format=ROW";
      networks = [
        "transport"
      ];
    };

    nextcloud-redis.service = {
      image = "redis:8.2-m01-alpine";
      container_name = "nextcloud-redis";
      restart = "unless-stopped";
      labels = {
        "traefik.enable" = "false";
      };
      networks = [
        "transport"
      ];
    };
  };
}

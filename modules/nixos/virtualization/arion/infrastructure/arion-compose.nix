{vars, ...}: {
  project.name = "infrastructure";

  docker-compose.volumes = {
    traefik-logs = null;
  };

  networks.dmz = {
    name = "dmz";
    external = true;
  };
  services = {
    traefik.service = {
      image = "traefik:latest";
      container_name = "traefik";
      useHostStore = true;
      ports = [
        "80:80"
        "81:81"
        "443:443"
        "444:444"
        "8421:8080"
      ];
      labels = {
        "traefik.enable" = "true";
        #"diun.enable" = "true";

        "traefik.http.routers.dashboard.rule" = "Host(`traefik.deadmade.de`)";
        "traefik.http.routers.dashboard.entrypoints" = "websecure";
        "traefik.http.services.dashboard.loadbalancer.server.port" = "8080";
        "traefik.http.routers.dashboard.tls" = "true";
        "traefik.http.routers.dashboard.tls.certresolver" = "letsencrypt";

        "traefik.http.routers.dashboard.tls.domains[0].main" = "deadmade.de";
        "traefik.http.routers.dashboard.tls.domains[0].sans" = "*.deadmade.de";

        "traefik.http.middlewares.traefik-https-redirect.redirectscheme.scheme" = "https";
        "traefik.http.middlewares.sslheader.headers.customrequestheaders.X-Forwarded-Proto" = "https";
      };
      volumes = [
        "/home/deadmade/.docker/infrastructure/traefik_config/traefik.yml:/traefik.yml:ro"
        "/home/deadmade/.docker/infrastructure/traefik_config/conf:/conf:ro"
        "/home/deadmade/.docker/infrastructure/traefik_data/acme.json:/acme.json"
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "traefik-logs:/var/log/traefik"
      ];
      env_file = [
        "/home/deadmade/.docker/infrastructure/traefik.env"
      ];
      restart = "always";
      networks = [
        "dmz"
      ];
    };
    # crowdsec.service = {
    #   image = "crowdsecurity/crowdsec:latest";
    #   container_name = "crowdsec";
    #   ports = [
    #     "127.0.0.1:9876:8080" # port mapping for local firewall bouncers
    #   ];
    #   environment = {
    #     GID = "1000";
    #     COLLECTIONS = "crowdsecurity/linux crowdsecurity/traefik firix/authentik LePresidente/gitea Dominic-Wagner/vaultwarden crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching";
    #   };
    #   volumes = [
    #     #"/home/deadmade/.docker/infrastructure/crowdsec_config/acquis.yaml:/etc/crowdsec/acquis.yaml:ro"
    #     #"/home/deadmade/.docker/infrastructure/crowdsec_config/profiles.yaml:/etc/crowdsec/profiles.yaml:ro"
    #     #"/home/deadmade/.docker/infrastructure/crowdsec_config/ntfy.yaml:/etc/crowdsec/notifications/ntfy.yaml:ro"
    #     "/home/deadmade/.docker/infrastructure/crowdsec_db:/var/lib/crowdsec/data/"
    #     "/home/deadmade/.docker/infrastructure/crowdsec_data:/etc/crowdsec/"
    #     "traefik-logs:/var/log/traefik/:ro"
    #     "/var/run/docker.sock:/var/run/docker.sock:ro"
    #   ];
    #   labels = {
    #     #"diun.enable" = "true";
    #     #"diun.include_tags" = "^v\\d+\\.\\d+\\.\\d+$$";
    #   };
    #   depends_on = [
    #     "traefik"
    #   ];
    #   networks = [
    #     "dmz"
    #   ];
    #   restart = "always";
    # };
    # bouncer-traefik.service = {
    #   image = "fbonalair/traefik-crowdsec-bouncer:latest";
    #   environment = {
    #     CROWDSEC_AGENT_HOST = "crowdsec:8080";
    #     GIN_MODE = "release";
    #   };
    #   env_file = [
    #     "/home/deadmade/.docker/infrastructure/traefik-bouncer.env"
    #   ];
    #   depends_on = [
    #     "crowdsec"
    #   ];
    #   networks = [
    #     "dmz"
    #   ];
    #   restart = "always";
    # };
    cloudflared.service = {
      image = "cloudflare/cloudflared:latest";
      container_name = "cloudflared";
      env_file = [
        "/home/deadmade/.docker/infrastructure/cloudflared.env"
      ];
      command = "tunnel --no-autoupdate run";
      depends_on = [
        "traefik"
      ];
      networks = [
        "dmz"
      ];
      restart = "always"; # TODO Change
    };
  };
}

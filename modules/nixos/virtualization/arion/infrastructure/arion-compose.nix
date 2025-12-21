{...}: {
  project.name = "infrastructure";

  networks.dmz = {
    name = "dmz";
    external = true;
  };

  services = {
    traefik.service = {
      image = "traefik:v3.4.1";
      container_name = "traefik";
      useHostStore = true;
      ports = [
        "80:80"
        "443:443"
        "8432:8080"
      ];
      labels = {
        "traefik.enable" = "false";

        "traefik.http.routers.traefik.tls" = "true";
        "traefik.http.routers.traefik.tls.certresolver" = "cloudflare";
        "traefik.http.routers.traefik.entrypoints" = "websecure";
        "traefik.http.routers.traefik.rule" = "Host(`traefik.deadmade.de`)";
        "traefik.http.services.portainer.loadbalancer.server.port" = "8432";

        "traefik.http.routers.dashboard.tls.domains[0].main" = "deadmade.de";
        "traefik.http.routers.dashboard.tls.domains[0].sans" = "*.deadmade.de";

        "traefik.http.middlewares.traefik-https-redirect.redirectscheme.scheme" = "https";
        "traefik.http.middlewares.sslheader.headers.customrequestheaders.X-Forwarded-Proto" = "https";
      };
      volumes = [
        "/home/deadmade/.docker/infrastructure/traefik_config/traefik.yml:/traefik.yml:ro"
        "/home/deadmade/.docker/infrastructure/traefik_config/conf:/conf:ro"
        "/home/deadmade/.docker/infrastructure/traefik_data/certs/:/var/traefik/certs/:rw"
        "/var/run/docker.sock:/var/run/docker.sock:ro"
      ];
      env_file = [
        "/home/deadmade/.docker/infrastructure/traefik.env"
      ];
      restart = "unless-stopped";
      networks = [
        "dmz"
        "transport"
      ];
    };

    # crowdsec.service = {
    #   image = "crowdsecurity/crowdsec:v1.6.9";
    #   container_name = "crowdsec";
    #   ports = [
    #     "127.0.0.1:9876:8080" # port mapping for local firewall bouncers
    #   ];
    #   environment = {
    #     GID = "1000";
    #     # COLLECTIONS = "crowdsecurity/linux crowdsecurity/traefik firix/authentik LePresidente/gitea Dominic-Wagner/vaultwarden crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching";
    #     COLLECTIONS = "crowdsecurity/traefik crowdsecurity/http-cve crowdsecurity/base-http-scenarios crowdsecurity/sshd crowdsecurity/linux crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-crs";
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
    #   restart = "unless-stopped";
    # };

    # bouncer-traefik.service = {
    #   image = "fbonalair/traefik-crowdsec-bouncer:latest";
    #   container_name = "bouncer-traefik";
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
      image = "cloudflare/cloudflared:2025.6.1";
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
      restart = "unless-stopped";
    };

    portainerd.service = {
      image = "portainer/portainer-ce:2.31.1";
      container_name = "portainer";
      useHostStore = true;
      ports = [
        "8000:8000"
        "9000:9000"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.portainer.rule" = "Host(`portainer.home.deadmade.de`)";
        "traefik.http.routers.portainer.entrypoints" = "websecure";
        "traefik.http.services.portainer.loadbalancer.server.port" = "9000";
        "traefik.http.routers.portainer.tls" = "true";
        "traefik.http.routers.portainer.tls.certresolver" = "cloudflare";

        "traefik.http.routers.portainer.tls.domains[0].main" = "home.deadmade.de";
        "traefik.http.routers.portainer.tls.domains[0].sans" = "*.home.deadmade.de";

        "traefik.http.middlewares.portainer-https-redirect.redirectscheme.scheme" = "https";
        "traefik.http.middlewares.sslheader.headers.customrequestheaders.X-Forwarded-Proto" = "https";
      };
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/home/deadmade/.docker/infrastructure/portainer_data:/data"
      ];
      networks = [
        "dmz"
      ];
      restart = "unless-stopped";
    };
  };
}

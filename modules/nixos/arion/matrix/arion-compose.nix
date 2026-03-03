{...}: {
  project.name = "matrix";

  networks.dmz = {
    name = "dmz";
    external = true;
  };

  networks.transport = {};

  services = {
    synapse.service = {
      image = "matrixdotorg/synapse:v1.117.0";
      container_name = "matrix-synapse";
      useHostStore = true;
      labels = {
        "traefik.enable" = "true";

        "traefik.http.routers.matrix-client.rule" = "Host(`matrix.deadmade.de`) && PathPrefix(`/_matrix/client`)";
        "traefik.http.routers.matrix-client.entrypoints" = "websecure";
        "traefik.http.routers.matrix-client.tls" = "true";
        "traefik.http.routers.matrix-client.tls.certresolver" = "cloudflare";
        "traefik.http.routers.matrix-client.service" = "matrix-synapse";

        "traefik.http.routers.matrix-federation.rule" = "Host(`matrix.deadmade.de`) && (PathPrefix(`/_matrix/federation`) || PathPrefix(`/_matrix/key`))";
        "traefik.http.routers.matrix-federation.entrypoints" = "websecure";
        "traefik.http.routers.matrix-federation.tls" = "true";
        "traefik.http.routers.matrix-federation.tls.certresolver" = "cloudflare";
        "traefik.http.routers.matrix-federation.service" = "matrix-synapse";

        "traefik.http.services.matrix-synapse.loadbalancer.server.port" = "8008";
      };
      volumes = [
        "/home/deadmade/.docker/matrix/synapse/homeserver.yaml:/data/homeserver.yaml:ro"
        "/home/deadmade/.docker/matrix/synapse/data:/data"
      ];
      depends_on = [
        "matrix-db"
        "matrix-redis"
      ];
      env_file = [
        "/home/deadmade/.docker/matrix/synapse/matrix.env"
      ];
      environment = {
        SYNAPSE_CONFIG_PATH = "/data/homeserver.yaml";
      };
      restart = "unless-stopped";
      networks = [
        "dmz"
        "transport"
      ];
    };

    matrix-db.service = {
      image = "postgres:17-alpine";
      container_name = "matrix-db";
      env_file = [
        "/home/deadmade/.docker/matrix/synapse/matrix.env"
      ];
      labels = {
        "traefik.enable" = "false";
      };
      volumes = [
        "/home/deadmade/.docker/matrix/postgres:/var/lib/postgresql/data"
      ];
      restart = "unless-stopped";
      networks = [
        "transport"
      ];
    };

    matrix-redis.service = {
      image = "redis:8.2-m01-alpine";
      container_name = "matrix-redis";
      labels = {
        "traefik.enable" = "false";
      };
      restart = "unless-stopped";
      networks = [
        "transport"
      ];
    };

    coturn.service = {
      image = "instrumentisto/coturn:4.6.3-r0";
      container_name = "matrix-coturn";
      ports = [
        "3478:3478/tcp"
        "3478:3478/udp"
        "5349:5349/tcp"
        "5349:5349/udp"
        "49152-49200:49152-49200/udp"
      ];
      command = [
        "--no-cli"
        "--no-tlsv1"
        "--no-tlsv1_1"
        "--fingerprint"
        "--use-auth-secret"
        "--realm=deadmade.de"
        "--listening-port=3478"
        "--tls-listening-port=5349"
        "--min-port=49152"
        "--max-port=49200"
        "--static-auth-secret=$${SYNAPSE_TURN_SHARED_SECRET}"
      ];
      env_file = [
        "/home/deadmade/.docker/matrix/synapse/matrix.env"
      ];
      labels = {
        "traefik.enable" = "false";
      };
      restart = "unless-stopped";
      networks = [
        "dmz"
      ];
    };

    matrix-wellknown.service = {
      image = "nginx:1.27-alpine";
      container_name = "matrix-wellknown";
      labels = {
        "traefik.enable" = "true";

        "traefik.http.routers.matrix-wellknown.rule" = "Host(`deadmade.de`) && PathPrefix(`/.well-known/matrix`)";
        "traefik.http.routers.matrix-wellknown.entrypoints" = "websecure";
        "traefik.http.routers.matrix-wellknown.tls" = "true";
        "traefik.http.routers.matrix-wellknown.tls.certresolver" = "cloudflare";
        "traefik.http.routers.matrix-wellknown.service" = "matrix-wellknown";

        "traefik.http.services.matrix-wellknown.loadbalancer.server.port" = "80";

        "traefik.http.middlewares.matrix-wellknown-header.headers.customResponseHeaders.Content-Type" = "application/json";
        "traefik.http.routers.matrix-wellknown.middlewares" = "matrix-wellknown-header";
      };
      volumes = [
        "/home/deadmade/.docker/matrix/well-known/server.json:/usr/share/nginx/html/.well-known/matrix/server:ro"
        "/home/deadmade/.docker/matrix/well-known/client.json:/usr/share/nginx/html/.well-known/matrix/client:ro"
      ];
      restart = "unless-stopped";
      networks = [
        "dmz"
      ];
    };
  };
}

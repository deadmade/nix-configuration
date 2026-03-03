{
  config,
  vars,
  ...
}: {
  virtualisation.arion.projects.matrix.settings = {
    imports = [./arion-compose.nix];
  };

  networking.firewall = {
    allowedTCPPorts = [
      3478
      5349
    ];
    allowedUDPPorts = [
      3478
      5349
    ];
    allowedUDPPortRanges = [
      {
        from = 49152;
        to = 49200;
      }
    ];
  };

  sops.secrets."matrix/registration_shared_secret" = {
    owner = vars.username;
  };
  sops.secrets."matrix/macaroon_secret_key" = {
    owner = vars.username;
  };
  sops.secrets."matrix/form_secret" = {
    owner = vars.username;
  };
  sops.secrets."matrix/turn_shared_secret" = {
    owner = vars.username;
  };
  sops.secrets."matrix/postgres_user" = {
    owner = vars.username;
  };
  sops.secrets."matrix/postgres_password" = {
    owner = vars.username;
  };
  sops.secrets."matrix/postgres_db" = {
    owner = vars.username;
  };

  sops.templates."matrix.env" = {
    path = "/home/${vars.username}/.docker/matrix/synapse/matrix.env";
    owner = vars.username;
    mode = "0640";
    content = ''
      POSTGRES_USER="${config.sops.placeholder."matrix/postgres_user"}"
      POSTGRES_PASSWORD="${config.sops.placeholder."matrix/postgres_password"}"
      POSTGRES_DB="${config.sops.placeholder."matrix/postgres_db"}"
      SYNAPSE_REGISTRATION_SHARED_SECRET="${config.sops.placeholder."matrix/registration_shared_secret"}"
      SYNAPSE_MACAROON_SECRET_KEY="${config.sops.placeholder."matrix/macaroon_secret_key"}"
      SYNAPSE_FORM_SECRET="${config.sops.placeholder."matrix/form_secret"}"
      SYNAPSE_TURN_SHARED_SECRET="${config.sops.placeholder."matrix/turn_shared_secret"}"
    '';
  };

  sops.templates."matrix-homeserver.yaml" = {
    path = "/home/${vars.username}/.docker/matrix/synapse/homeserver.yaml";
    owner = vars.username;
    mode = "0640";
    content = ''
      server_name: "deadmade.de"
      pid_file: /data/homeserver.pid
      public_baseurl: "https://matrix.deadmade.de/"

      listeners:
        - port: 8008
          type: http
          tls: false
          x_forwarded: true
          resources:
            - names: [client, federation]
              compress: false

      database:
        name: psycopg2
        args:
          user: "${config.sops.placeholder."matrix/postgres_user"}"
          password: "${config.sops.placeholder."matrix/postgres_password"}"
          database: "${config.sops.placeholder."matrix/postgres_db"}"
          host: matrix-db
          port: 5432
          cp_min: 5
          cp_max: 10

      redis:
        enabled: true
        host: matrix-redis
        port: 6379

      registration_shared_secret: "${config.sops.placeholder."matrix/registration_shared_secret"}"
      macaroon_secret_key: "${config.sops.placeholder."matrix/macaroon_secret_key"}"
      form_secret: "${config.sops.placeholder."matrix/form_secret"}"

      enable_registration: false
      enable_registration_without_verification: false

      trusted_key_servers:
        - server_name: "matrix.org"

      turn_uris:
        - "turn:matrix.deadmade.de:3478?transport=udp"
        - "turn:matrix.deadmade.de:3478?transport=tcp"
        - "turns:matrix.deadmade.de:5349?transport=tcp"
      turn_shared_secret: "${config.sops.placeholder."matrix/turn_shared_secret"}"
      turn_user_lifetime: "1h"
      turn_allow_guests: true
    '';
  };

  sops.templates."matrix-wellknown-server.json" = {
    path = "/home/${vars.username}/.docker/matrix/well-known/server.json";
    owner = vars.username;
    mode = "0644";
    content = ''
      {"m.server":"matrix.deadmade.de:443"}
    '';
  };

  sops.templates."matrix-wellknown-client.json" = {
    path = "/home/${vars.username}/.docker/matrix/well-known/client.json";
    owner = vars.username;
    mode = "0644";
    content = ''
      {"m.homeserver":{"base_url":"https://matrix.deadmade.de"}}
    '';
  };

  systemd.tmpfiles.rules = [
    "d /home/${vars.username}/.docker/matrix 0750 ${vars.username} users -"
    "d /home/${vars.username}/.docker/matrix/synapse 0750 ${vars.username} users -"
    "d /home/${vars.username}/.docker/matrix/synapse/data 0750 ${vars.username} users -"
    "d /home/${vars.username}/.docker/matrix/postgres 0750 ${vars.username} users -"
    "d /home/${vars.username}/.docker/matrix/well-known 0755 ${vars.username} users -"
    "d /home/${vars.username}/.docker/matrix/coturn 0750 ${vars.username} users -"
  ];
}

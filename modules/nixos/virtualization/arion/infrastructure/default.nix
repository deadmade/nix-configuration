{
  config,
  vars,
  ...
}: {
  virtualisation.arion = {
    projects.infrastructure.settings = {
      imports = [./arion-compose.nix];
    };
  };

  sops.secrets."cloudflared/tunnel_token" = {
    owner = vars.username;
  };

  sops.secrets."traefik/acme_email" = {
    owner = vars.username;
  };
  sops.secrets."traefik/cloudflare_email" = {
    owner = vars.username;
  };
  sops.secrets."traefik/cloudflare_api_key" = {
    owner = vars.username;
  };

  sops.secrets."crowdsec/traefik_bouncer_api_key" = {
    owner = vars.username;
  };

  sops.secrets."diun/ntfy_access_token" = {
    owner = vars.username;
  };

  sops.templates."cloudflared.env" = {
    path = "/home/${vars.username}/.docker/infrastructure/cloudflared.env";
    owner = vars.username;
    mode = "0775";
    content = ''
      TUNNEL_TOKEN="${config.sops.placeholder."cloudflared/tunnel_token"}"
    '';
  };

  sops.templates."traefik.env" = {
    path = "/home/${vars.username}/.docker/infrastructure/traefik.env";
    owner = vars.username;
    mode = "0775";
    content = ''
      CLOUDFLARE_EMAIL="${config.sops.placeholder."traefik/cloudflare_email"}"
      CLOUDFLARE_API_KEY="${config.sops.placeholder."traefik/cloudflare_api_key"}"
    '';
  };

  sops.templates."traefik-bouncer.env" = {
    path = "/home/${vars.username}/.docker/infrastructure/traefik-bouncer.env";
    owner = vars.username;
    mode = "0775";
    content = ''
      CROWDSEC_BOUNCER_API_KEY="${config.sops.placeholder."crowdsec/traefik_bouncer_api_key"}"
    '';
  };

  sops.templates."traefik.yml" = {
    path = "/home/${vars.username}/.docker/infrastructure/traefik_config/traefik.yml";
    owner = vars.username;
    mode = "0775";
    content = ''
      api:
        dashboard: true
        debug: true
        insecure: true
      entryPoints:
        web:
          address: ":80"
          http:
            redirections:
              entrypoint:
                to: websecure
                scheme: https
        websecure:
          address: ":443"
        web-external:
          address: ":81"
          http:
            redirections:
              entrypoint:
                to: websecure-external
                scheme: https
            middlewares:
              - crowdsec-bouncer@file
        websecure-external:
          address: ":444"
          http:
            middlewares:
              - crowdsec-bouncer@file
      providers:
        docker:
          watch: true
          exposedByDefault: false
          network: dmz
        file:
          watch: true
          directory: /conf/
      certificatesResolvers:
        letsencrypt:
          acme:
            email: ${config.sops.placeholder."traefik/acme_email"}
            storage: acme.json
            dnsChallenge:
              provider: cloudflare
              resolvers:
                - "1.1.1.1:53"
                - "1.0.0.1:53"
      log:
        level: "INFO"
        filePath: "/var/log/traefik/traefik.log"
      accessLog:
        filePath: "/var/log/traefik/access.log"
    '';
  };

  sops.templates."diun.env" = {
    path = "/home/${vars.username}/.docker/infrastructure/diun.env";
    owner = vars.username;
    mode = "0775";
    content = ''
      DIUN_NOTIF_NTFY_TOKEN="${config.sops.placeholder."diun/ntfy_access_token"}"
    '';
  };
  services.cron = {
    enable = true;
    systemCronJobs = [
      "0 * * * *      root    . /etc/profile; docker exec crowdsec cscli hub update && docker exec crowdsec cscli hub upgrade >> /var/log/crowdsec-update.log"
    ];
  };
}

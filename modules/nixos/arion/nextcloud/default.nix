{
  config,
  vars,
  ...
}: {
  virtualisation.arion = {
    projects.nextcloud.settings = {
      imports = [./arion-compose.nix];
    };
  };

  services.cron = {
    enable = true;
    systemCronJobs = [
      "*/5 * * * *      root    . /etc/profile; docker exec -u www-data nextcloud php /var/www/html/cron.php"
    ];
  };

  sops.secrets."nextcloud/mysql_root_password" = {
    owner = vars.username;
  };
  sops.secrets."nextcloud/mysql_password" = {
    owner = vars.username;
  };
  sops.secrets."nextcloud/mysql_database" = {
    owner = vars.username;
  };
  sops.secrets."nextcloud/mysql_user" = {
    owner = vars.username;
  };

  sops.templates."nextcloud.env" = {
    path = "/home/${vars.username}/.docker/nextcloud/nextcloud.env";
    owner = vars.username;
    mode = "0775";
    content = ''
      MYSQL_ROOT_PASSWORD="${config.sops.placeholder."nextcloud/mysql_root_password"}"
      MYSQL_PASSWORD="${config.sops.placeholder."nextcloud/mysql_password"}"
      MYSQL_DATABASE="${config.sops.placeholder."nextcloud/mysql_database"}"
      MYSQL_USER="${config.sops.placeholder."nextcloud/mysql_user"}"
    '';
  };
}

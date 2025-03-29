{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    inputs.arion.nixosModules.arion
  ];

  environment.systemPackages = with pkgs; [arion];

  virtualisation.arion.backend = "docker";

  systemd.services.init-dmz-bridge-network = {
    description = "Create the network bridge dmz for the Docker stack.";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig.Type = "oneshot";
    script = let
      dockercli = "${config.virtualisation.docker.package}/bin/docker";
    in ''
      # Put a true at the end to prevent getting non-zero return code, which will
      # crash the whole service.
      check=$(${dockercli} network ls | grep "dmz" || true)
      if [ -z "$check" ]; then
        ${dockercli} network create dmz
      else
        echo "dmz already exists in docker"
      fi
    '';
  };
}

{
  config,
  var,
  ...
}: {
  virtualisation.arion = {
    projects.infrastructure.settings = {
      imports = [./arion-compose.nix];
    };
  };
}

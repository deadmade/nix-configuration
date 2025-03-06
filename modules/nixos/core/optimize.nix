{
  # Optimize the Nix store
  nix.optimise.automatic = true;
  nix.settings.auto-optimise-store = true;

  # Collect garbage automatically
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}

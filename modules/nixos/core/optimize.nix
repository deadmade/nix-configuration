{
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
    };
    gc = {
      automatic = false;
      dates = "weekly";
      options = "--delete-older-than +3";
    };
  };
}

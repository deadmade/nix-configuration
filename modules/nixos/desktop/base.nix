{pkgs, ...}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  environment.pathsToLink = ["/share/zsh"];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
    config = {
      common.default = ["hyprland" "gtk"];
    };
  };

  # Shared desktop audio stack.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}

{
  pkgs,
  inputs,
  ...
}: {
  # Home Manager Settings
  home.username = "deadmade";
  home.homeDirectory = "/home/deadmade";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
  ];

  # Optional, hint Electron apps to use Wayland
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable Home Manager
  programs.home-manager.enable = true;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [
      "--cmd z"
    ];
  };

  programs.superfile = {
    enable = true;
    settings = {
      metadata = true;
      zoxide = true;
    };
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}

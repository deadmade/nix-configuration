{
  inputs,
  pkgs,
  username,
  host,
  ...
}: let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in {
  imports = [
    ../../packageConfigurations/windowManager/hyprland/hyprland.nix
    ../../packageConfigurations/VsCodium/VsCodium.nix
    ../../packageConfigurations/terminal/kitty/kitty.nix
    ../../packageConfigurations/terminal/tmux/tmux.nix
    ../../packageConfigurations/terminal/zsh/zsh.nix
    (import ../../packageConfigurations/floorp/floorp.nix {inherit inputs pkgs;})
    ../../packageConfigurations/flatpak/flatpak.nix
  ];

  # Home Manager Settings
  home.username = "deadmade";
  home.homeDirectory = "/home/deadmade";
  home.stateVersion = "24.11";

  # Install & Configure Git
  programs.git = {
    enable = true;
    userName = gitUsername;
    userEmail = gitEmail;
  };

  #programs.bash.enable = true;

  # Install & Configure GitHub CLI
  programs.gh.enable = true;

  # Install & Configure btop
  # programs.btop = {
  #   enable = true;
  #   settings = {
  #     vim_keys = true;
  #   };
  # };

  # Install & Configure Starship
  programs.starship = {
    enable = true;
    settings = pkgs.lib.importTOML ../../packageConfigurations/starship/starship.toml;
    enableZshIntegration = true;
  };

  # Optional, hint Electron apps to use Wayland:
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  # Install & Configure Greetd
  #programs.greetd = {
  # enable = true;
  #settings = {
  # default_session = {
  #  command = "${pkgs.greetd.greetd}/bin/agreety --cmd Hyprland";
  #};
  #};
  #};

  home.packages = with pkgs; [
    remnote
  ];

  # Enable Home Manager
  programs.home-manager.enable = true;
}

{
  pkgs,
  username,
  host,
  ...
}:
let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in
{

  # imports = [
  #   ../../packageConfigurations/hyprland/hyprland.nix
  # ];

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

  # Install & Configure GitHub CLI
  programs.gh.enable = true;

  # Install & Configure btop
  # programs.btop = {
  #   enable = true;
  #   settings = {
  #     vim_keys = true;
  #   };
  # };

  # Install & Configure Kitty
  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    settings = {
      scrollback_lines = 2000;
      wheel_scroll_min_lines = 1;
      window_padding_width = 4;
      confirm_os_window_close = 0;
    };
    extraConfig = ''
      tab_bar_style fade
      tab_fade 1
      active_tab_font_style   bold
      inactive_tab_font_style bold
    '';
  };

  # Install & Configure Starship
  # programs.starship = {
  #   enable = true;
  #   settings = pkgs.lib.importTOML ../../packageConfigurations/starship/starship.toml;
  #   enableZshIntegration = true;
  # };

  # Install & Configure Hyprland
  #wayland.windowManager.hyprland.enable = true; # enable Hyprland

  # Optional, hint Electron apps to use Wayland:
  #home.sessionVariables.NIXOS_OZONE_WL = "1";

  # Install & Configure Greetd
  # programs.greetd = {
  #   enable = true;
  #   settings = {
  #     default_session = {
  #       command = "${pkgs.greetd.greetd}/bin/agreety --cmd Hyprland";
  #     };
  #   };
  # };

  # Enable Home Manager
  programs.home-manager.enable = true;
}

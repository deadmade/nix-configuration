{
  defaultConfig = import ./home-manager.nix;
  browser = import ../packageConfigurations/browser;
  hyprland = import ../packageConfigurations/windowManager/hyprland;
}

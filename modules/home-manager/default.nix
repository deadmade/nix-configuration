{
  defaultConfig = import ./home-manager.nix;
  browser = import ../../packageConfigurations/browser;
  hyprland = import ../../packageConfigurations/windowManager/hyprland;
  coding = import ../../packageConfigurations/coding;
  terminal = import ../../packageConfigurations/terminal;
  gaming = import ../../packageConfigurations/gaming;
}

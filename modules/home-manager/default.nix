{
  core = import ./core;
  defaultConfig = import ./home-manager.nix;
  browser = import ./browser;
  hyprland = import ./windowManager/hyprland;
  coding = import ./coding;
  terminal = import ./terminal;
  gaming = import ./gaming;
}

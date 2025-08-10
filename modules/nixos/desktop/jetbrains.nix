{
  config,
  pkgs,
  inputs,
  outputs,
  system,
  ...
}: let
  pluginList = [
    # hotkeys
    "164" # ideavim

    # themes
    "18682" # catppuccin-theme
    "23029" # catppuccin-icons

    # fun
    "8575" # nyan-progress-bar
    "24027" # discord-rich-presence

    # ai
    "17718" # copilt
  ];

  pluginListPy = [
  ];

  addPlugins = (inputs.nix-jetbrains-plugins.import pkgs.unstable).addPlugins;

  idea-community = addPlugins pkgs.jetbrains.idea-community-bin pluginList;
  rider = addPlugins pkgs.jetbrains.rider pluginList;
  pycharm-community = addPlugins pkgs.jetbrains.pycharm-professional pluginList;
  webstorm = addPlugins pkgs.jetbrains.webstorm pluginList;
  rust-rover = addPlugins pkgs.jetbrains.rust-rover pluginList;
in {
  environment.systemPackages = [
    #    idea-community
    rider
    # pycharm-community
    # webstorm
    rust-rover
  ];
}

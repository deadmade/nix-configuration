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
    "17718" # copilot
  ];

  addPlugins = (inputs.nix-jetbrains-plugins.import pkgs.unstable).addPlugins;

  idea-community = addPlugins pkgs.unstable.jetbrains.idea-community-bin pluginList;
  rider = addPlugins pkgs.unstable.jetbrains.rider pluginList;
  pycharm-community = addPlugins pkgs.unstable.jetbrains.pycharm-community-bin pluginList;
  webstorm = addPlugins pkgs.unstable.jetbrains.webstorm pluginList;
in {
  environment.systemPackages = [
    #    idea-community
    rider
   # pycharm-community
    # webstorm
  ];
}

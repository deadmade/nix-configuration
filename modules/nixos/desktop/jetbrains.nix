{
  config,
  pkgs,
  inputs,
  outputs,
  system,
  ...
}: let
  pluginList = [
    "IdeaVIM"
    "io.github.pandier.intellijdiscordrp"
    "com.github.catppuccin.jetbrains"
    "com.github.mousechannel.jetbrains_icons"
    "com.github.copilot"
  ];
in {
  environment.systemPackages = with inputs.nix-jetbrains-plugins.lib."${pkgs.system}"; [
    (buildIdeWithPlugins pkgs.jetbrains "rider" pluginList)
    (buildIdeWithPlugins pkgs.jetbrains "webstorm" pluginList)
    (buildIdeWithPlugins pkgs.jetbrains "rust-rover" pluginList)
    (buildIdeWithPlugins pkgs.jetbrains "pycharm-professional" pluginList)
  ];
}

{
  pkgs,
  inputs,
  lib,
  ...
}: let
  inherit (pkgs.jetbrains) pycharm;
  plugins = inputs.nix-jetbrains-plugins.lib.pluginsForIde pkgs pycharm [
    "IdeaVIM"
    "io.github.pandier.intellijdiscordrp"
    "com.github.catppuccin.jetbrains"
    "com.github.catppuccin.jetbrains_icons"
    "com.github.copilot"
    "izhangzhihao.rainbow.brackets.lite"
    "some.awesome"
    "com.clutcher.comments_highlighter"
    "mobi.hsz.idea.gitignore"
    "com.github.lppedd.idea-conventional-commit"
    "com.dsoftware.ghtoolbar"
  ];
in {
  environment.systemPackages = with inputs.nix-jetbrains-plugins.lib; [
    #(buildIdeWithPlugins pkgs "rider" pluginList)
    #(buildIdeWithPlugins pkgs "webstorm" pluginList)
    #(buildIdeWithPlugins pkgs "rust-rover" pluginList)
    #(buildIdeWithPlugins pkgs "pycharm" pluginList)
    #(buildIdeWithPlugins pkgs "jetbrains.datagrip")
    (pkgs.jetbrains.plugins.addPlugins pycharm (lib.attrValues plugins))
  ];
}

{
  config,
  pkgs,
  inputs,
  outputs,
  system,
  ...
}: let 
  # pluginList = [
  #  inputs.nix-jetbrains-plugins.plugins."${system}".idea-ultimate."2024.3"."com.intellij.plugins.watcher"
  # ];
in {
  environment.systemPackages = with pkgs.unstable; [
   jetbrains.rider
   # jetbrains.webstorm
   # jetbrains.pycharm-professional
   (pkgs.jetbrains.plugins.addPlugins pkgs.jetbrains.rider ["ideavim" "catppuccin-theme" "catppuccin-icons"])
  ];
}

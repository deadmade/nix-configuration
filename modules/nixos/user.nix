{pkgs, ...}: let
  inherit (import ../../variables.nix) username;
in {
  programs.zsh.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.zsh; #TODO Make this configurable
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      #  kdePackages.kate
      #  thunderbird
    ];
  };
}

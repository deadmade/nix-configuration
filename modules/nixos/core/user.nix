{
  pkgs,
  vars,
  ...
}: {
  programs.zsh.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    shell = pkgs.zsh; #TODO Make this configurable
    extraGroups = ["networkmanager" "wheel" "dialout" "docker"];
    packages = with pkgs; [
      home-manager
    ];
  };

  nix.settings.trusted-users = [vars.username];
}

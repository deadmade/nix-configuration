{
  pkgs,
  vars,
  ...
}: {
  programs.zsh.enable = true;

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    shell = pkgs.zsh;
    extraGroups = ["networkmanager" "wheel" "dialout"];
    packages = with pkgs; [
    ];
  };

  nix.settings.trusted-users = [vars.username];
}

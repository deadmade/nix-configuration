{pkgs, ...}: {
  home.username = "deadmade";
  home.homeDirectory = "/home/deadmade";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
  ];

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.home-manager.enable = true;

  programs.zoxide = {
    enable = true;
    package = pkgs.unstable.zoxide;
    enableZshIntegration = true;
    options = [
      "--cmd z"
    ];
  };

  programs.superfile = {
    enable = true;
    package = pkgs.unstable.superfile;
    settings = {
      metadata = true;
      zoxide = true;
    };
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}

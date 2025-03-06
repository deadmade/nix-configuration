{
  inputs,
  outputs,
  pkgs,
  lib,
  username,
  host,
  ...
}: let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in {
  imports = [
    ../../packageConfigurations/flatpak
    inputs.stylix.homeManagerModules.stylix
  ];

  # Home Manager Settings
  home.username = "deadmade";
  home.homeDirectory = "/home/deadmade";
  home.stateVersion = "24.11";

  # # Install & Configure Git
  programs.git = {
    enable = true;
    userName = gitUsername;
    userEmail = gitEmail;
  };

  # Install & Configure GitHub CLI
  programs.gh.enable = true;

  # Install & Configure btop
  # programs.btop = {
  #   enable = true;
  #   settings = {
  #     vim_keys = true;
  #   };
  # };

  # Optional, hint Electron apps to use Wayland:
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  home.packages = with pkgs; [
  ];

  nixpkgs = {
    overlays =
      [
      ]
      ++ (builtins.attrValues outputs.overlays);
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
      ];
    };
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
    };
  };

  # Stylix
  stylix = {
    enable = true;
    image = ../../wallpapers/stylix/bloodMoon.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";

    autoEnable = true;

    polarity = "dark";
    opacity = {
      terminal = 0.8;
      desktop = 0.0;
    };
    cursor.package = pkgs.bibata-cursors;
    cursor.name = "Bibata-Modern-Ice";
    cursor.size = 25;
    fonts = {
      monospace = {
        package = pkgs.unstable.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
    };
  };

  # Enable Home Manager
  programs.home-manager.enable = true;
}

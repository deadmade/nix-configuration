{
  outputs,
  pkgs,
  config,
  ...
}: {
  imports =
    [
      outputs.homeManagerModules.hyprland
      outputs.homeManagerModules.coding
      outputs.homeManagerModules.browser.librewolf
      outputs.homeManagerModules.socialMedia.vencord
      outputs.homeManagerModules.flatpak
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core)
    ++ (builtins.attrValues outputs.homeManagerModules.terminal);

  home.packages = with pkgs; [
    pkgs.unstable.p3x-onenote
    teams-for-linux
  ];

  nixpkgs = {
    overlays = [
      outputs.overlays.unstable-packages
      outputs.overlays.modifications
    ];
    config.allowUnfree = true;
  };

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "eDP-1, 1920x1200@60,0x0,1"
      ];

      bind = [
        "$mainMod, F5,exec,brightnessctl set 10%-"
        "$mainMod, F6,exec,brightnessctl set 10%+"
      ];
    };
  };

  services.wpaperd = {
    settings = {
      eDP-1 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
    };
  };

  home.shellAliases = {
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadConvertible && home-manager switch --flake .#deadmade@deadConvertible";
  };
}

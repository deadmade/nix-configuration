{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  _module.args = {
    vars = {
      gitUsername = "deadmade";
      gitEmail = "manuel.schuelein@proton.me";
      username = "deadmade";
      # Consumed by modules/home-manager/windowManager/hyprland/config.nix.
      browser = "librewolf";
      terminal = "ghostty";
      keyboardLayout = "de";
      consoleKeyMap = "de";
    };
    hostDefinitions = import ../../hosts/hosts.nix;
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}

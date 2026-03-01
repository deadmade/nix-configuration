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
      browser = "brave";
      terminal = "kitty";
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

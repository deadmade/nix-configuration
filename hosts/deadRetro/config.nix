{
  pkgs,
  lib,
  ...
}: {
  services.xserver = {
    enable = true;
    displayManager.kdm.enable = true;
    desktopManager.kde4.enable = true;
    layout = "de";

    resolutions = lib.mkOverride 5 [
      {
        x = 1920;
        y = 1200;
      }
    ];
  };

  environment.etc."xdg/kwinrc".text = ''
    [Compositing]
    Enabled=false
  '';

  environment.systemPackages = with pkgs; [
    kde4.kdegraphics
    kde4.kdemultimedia
    kde4.kdenetwork
    kde4.kdegames
    kde4.kdetoys
    kde4.yakuake
    kde4.konversation
    audacious
    clementine
    pidgin
    xchat
    abiword
    gnumeric
    conky
    vlc
  ];

  users.extraUsers.retro = {
    isNormalUser = true;
    password = "retro";
    extraGroups = ["wheel" "audio" "video"];
  };

  networking.useDHCP = false;

  virtualisation = {
    memorySize = 4096;

    diskSize = 8192;

    diskImage = "$HOME/.local/share/deadRetro/deadRetro.qcow2";

    qemu.networkingOptions = ["-net none"];

    qemu.options = lib.mkForce [
      "-accel kvm"
      "-cpu host"
      "-smp 4"

      "-vga none"
      "-device VGA,vgamem_mb=32"

      "-usb"
      "-device usb-tablet"
    ];
  };
}

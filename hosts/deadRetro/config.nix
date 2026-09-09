# System configuration for the deadRetro VM.
#
# This is evaluated against nixpkgs 14.12 (via nixpkgs-multiverse), NOT against
# the flake's 26.05 nixpkgs -- only options that existed in that release are
# available here. See ./default.nix for the evaluation and launcher.
{
  pkgs,
  lib,
  ...
}: {
  services.xserver = {
    enable = true;
    displayManager.kdm.enable = true;
    desktopManager.kde4.enable = true;

    # The VM runs with `-vga qxl`, but 14.12's default videoDrivers list has no
    # qxl entry, so X would fall back to vesa and ignore `resolutions` below.
    videoDrivers = ["qxl" "modesetting" "vesa"];

    resolutions = [
      {
        x = 1920;
        y = 1080;
      }
    ];

    layout = "de";
  };

  environment.systemPackages = with pkgs; [
    kde4.kdegraphics
    kde4.kdemultimedia
    kde4.kdenetwork # Includes Kopete
    kde4.kdegames # Classic KDE games
    kde4.kdetoys # AMOR, KTeaTime
    kde4.yakuake # Iconic drop-down terminal
    kde4.konversation # KDE IRC client
    audacious
    clementine # Amarok fork! peak 2014 music
    pidgin
    xchat # Classic GTK IRC
    abiword # Lightweight word processor
    gnumeric # Spreadsheet
    conky
    vlc
    firefox
  ];

  users.extraUsers.retro = {
    isNormalUser = true;
    password = "retro";
    extraGroups = ["wheel" "audio" "video"];
  };

  virtualisation = {
    memorySize = 4096;

    # 14.12 defaults to 512M, which a KDE 4 session fills up quickly.
    diskSize = 8192;

    # The default is "./nixos.qcow2", i.e. relative to whatever directory the
    # VM was launched from -- which dropped a disk image into the flake repo.
    # $HOME is expanded by the generated start script at runtime; the launcher
    # in ./default.nix creates the directory.
    diskImage = "$HOME/.local/share/deadRetro/deadRetro.qcow2";

    # qemu-vm.nix in 14.12 sets these in `config` rather than as an option
    # default, so replacing them needs mkForce.
    qemu.options = lib.mkForce ["-vga qxl" "-smp 4" "-usbdevice tablet"];
  };
}

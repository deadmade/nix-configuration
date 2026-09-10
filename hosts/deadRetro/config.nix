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
    layout = "de";

    # qemu-vm.nix pins this with mkVMOverride, i.e. priority 10. A plain
    # definition -- and even mkForce, which is only 50 -- loses against that and
    # is silently dropped, so this needs a lower priority number to apply.
    #
    # 1920x1080 is not reachable here: the guest drives qemu's stdvga through
    # bochs-drm, and the 3.14 kernel's mode list for it is the VESA DMT table,
    # which has no 1920x1080 entry. A resolution that is not in that list is
    # ignored and X falls back to the largest mode that fits in video RAM.
    # 1920x1200 is in the table.
    resolutions = lib.mkOverride 5 [
      {
        x = 1920;
        y = 1200;
      }
    ];
  };

  # There is no GPU here -- X does every operation as a software blit and GLX
  # is swrast -- so KDE's compositor only adds latency. Set as a system-wide
  # default in /etc/xdg, so it can still be turned back on per user.
  environment.etc."xdg/kwinrc".text = ''
    [Compositing]
    Enabled=false
  '';

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
  ];

  users.extraUsers.retro = {
    isNormalUser = true;
    password = "retro";
    extraGroups = ["wheel" "audio" "video"];
  };

  # The VM gets no network device at all (see qemu.networkingOptions below), so
  # skip the DHCP client rather than let it retry against a NIC that is absent.
  networking.useDHCP = false;

  virtualisation = {
    memorySize = 4096;

    # 14.12 defaults to 512M, which a KDE 4 session fills up quickly.
    diskSize = 8192;

    # The default is "./nixos.qcow2", i.e. relative to whatever directory the
    # VM was launched from -- which dropped a disk image into the flake repo.
    # $HOME is expanded by the generated start script at runtime; the launcher
    # in ./default.nix creates the directory.
    diskImage = "$HOME/.local/share/deadRetro/deadRetro.qcow2";

    # No networking. This is an unpatched 2014 distro with a 2014 browser;
    # nothing good happens if it can reach the internet.
    qemu.networkingOptions = ["-net none"];

    # qemu-vm.nix in 14.12 sets these in `config` rather than as an option
    # default, so replacing them needs mkForce.
    qemu.options = lib.mkForce [
      # The 14.12 qemu wrapper passed -enable-kvm implicitly; the host qemu
      # ./default.nix substitutes defaults to TCG emulation, which is unusably
      # slow. -cpu host overrides the -cpu kvm64 the start script hardcodes,
      # which otherwise hides SSE4/AVX from the guest -- and every pixel this
      # VM draws goes through software rasterisation.
      "-accel kvm"
      "-cpu host"
      "-smp 4"

      # NOT -vga qxl. The guest's qxl DRM driver never hands qemu a primary
      # surface, so the display freezes on the last text-mode frame partway
      # through boot -- the "black screen after startup". stdvga goes through
      # bochs-drm and renders correctly. 32M of video RAM is what makes modes
      # above 1600x1200 available.
      "-vga none"
      "-device VGA,vgamem_mb=32"

      "-usb"
      "-device usb-tablet"
    ];
  };
}

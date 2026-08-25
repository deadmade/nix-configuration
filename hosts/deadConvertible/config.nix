{
  pkgs,
  outputs,
  inputs,
  ...
}: {
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      inputs.hardware.nixosModules.common-cpu-amd
      inputs.hardware.nixosModules.common-gpu-amd
      inputs.hardware.nixosModules.common-pc-laptop
      inputs.hardware.nixosModules.common-pc-ssd

      outputs.nixosModules.desktop.bluetooth
      outputs.nixosModules.desktop.packages
      outputs.nixosModules.desktop.stylix
      outputs.nixosModules.desktop.ai
      outputs.nixosModules.virtualization.container
    ]
    ++ (builtins.attrValues outputs.nixosModules.core);

  environment.pathsToLink = ["/share/zsh"];

  networking.hostName = "deadConvertible"; # Define your hostname.
  networking.networkmanager.enable = true;
  #networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable the X11 windowing system.
  services.xserver.enable = false;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = ["evdi" "wacom"];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
    config = {
      common.default = "hyprland";
    };
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  # Enable CUPS to print documents.
  services.printing.enable = false;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = false;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  services.libinput.touchpad.tapping = true;
  services.libinput.touchpad.clickMethod = "clickfinger";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    tuigreet
    inputs.neovim-config.packages.${pkgs.stdenv.hostPlatform.system}.nvim
    #inputs.chiplang-nix.packages.${pkgs.stdenv.hostPlatform.system}.depthfinder
    brightnessctl
    glab
    pkgs.unstable.vscode
  ];

  #network display + ssh
  networking.firewall.allowedTCPPorts = [7236 7250 22];
  networking.firewall.allowedUDPPorts = [7236 5353];

  services.greetd = {
    enable = true;
    #vt = 3;
    settings = {
      default_session = {
        user = "deadmade";
        command = "${pkgs.tuigreet}/bin/tuigreet
        --time
        --issue
        --asterisks
        --theme border=magenta;text=cyan;prompt=green;time=red;action=blue;button=yellow;container=black;input=red
        --cmd Hyprland"; # start Hyprland with a TUI login manager
      };
    };
  };

  hardware = {
    graphics.enable = true;
    graphics.enable32Bit = true;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon (home network / LAN access).
  services.openssh = {
    enable = true;
    settings = {
      # Password auth is fine for a home LAN; switch to key-only
      # (PasswordAuthentication = false) once you've added a key.
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];  # ssh (22) added above
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}

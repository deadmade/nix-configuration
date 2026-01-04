# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
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

      outputs.nixosModules.desktop.packages
      outputs.nixosModules.desktop.stylix
      outputs.nixosModules.desktop.vpn
      outputs.nixosModules.virtualization.vm
    ]
    ++ (builtins.attrValues outputs.nixosModules.core);

  nix.settings.experimental-features = ["nix-command" "flakes"];

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

  hardware.cpu.amd.updateMicrocode = true;

  # Enable CUPS to print documents.
  services.printing.enable = false;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  services.libinput.touchpad.tapping = true;
  services.libinput.touchpad.clickMethod = "clickfinger";

  # Allow unfree packages
  nixpkgs = {
    overlays = [
      outputs.overlays.unstable-packages
      outputs.overlays.modifications
    ];
    config.allowUnfree = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    tuigreet
    inputs.neovim-config.packages.${pkgs.system}.nvim
    brightnessctl

    #dive # look into docker image layers
    #podman-tui # status of containers in the terminal
    #docker-compose # start group of containers for dev
    #unstable.podman-compose # start group of containers for dev
    #unstable.podman-desktop
  ];

  services.greetd = {
    enable = true;
    #vt = 3;
    settings = {
      default_session = {
        user = "deadmade";
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet 
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

  virtualisation.containers.enable = true;
  # virtualisation = {
  #   podman = {
  #     enable = true;

  #     # Create a `docker` alias for podman, to use it as a drop-in replacement
  #     dockerCompat = true;

  #     # Required for containers under podman-compose to be able to talk to each other.
  #     defaultNetwork.settings.dns_enabled = true;
  #   };
  # };

  virtualisation.docker.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
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

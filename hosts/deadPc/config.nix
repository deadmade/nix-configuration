{
  config,
  pkgs,
  outputs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./mainboard.nix

    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.hardware.nixosModules.common-pc-ssd

    inputs.nix-mineral.nixosModules.nix-mineral

    outputs.nixosProfiles.desktopAll
    outputs.nixosModules.virtualization.vmware
  ];

  # Security hardening via nix-mineral (alpha software — see overrides below).
  # Rebuild with `nixos-rebuild boot` + reboot so the previous generation stays
  # available in the bootloader for rollback.
  nix-mineral = {
    enable = true;
    preset = ["default"]; # balanced; "maximum" = stricter, "compatibility" = relax for gaming

    # --- Likely-needed relaxations for a gaming desktop. Uncomment as needed. ---
    settings = {
      # 32-bit libraries for Steam / Proton / Wine:
      # system.multilib = true;
      # Relax process-tracing restriction (some anti-cheat / debuggers / Gamescope):
      # system.yama = "relaxed";
      # If lockdown or only-signed-modules blocks the NVIDIA stack / hibernation:
      # kernel.lockdown = false;
      # kernel.only-signed-modules = false;
    };

    # Allow executing binaries from home and /tmp (Steam shaders, launchers, installers):
    # filesystems.normal."/home".options."noexec" = false;
    # filesystems.normal."/tmp".options."noexec" = false;
  };

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];

  # Enable cross-compilation support
  nix.settings.extra-platforms = config.boot.binfmt.emulatedSystems;

  networking.hostName = "deadPc"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  #networking.networkmanager.enable = true;

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false;

  # Enable CUPS to print documents.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };
  services.printing = {
    enable = false;
    browsing = true;
    drivers = [pkgs.cnijfilter2 pkgs.canon-cups-ufr2];
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Enable Pipewire (required for Wayland screen sharing)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.deadmade = {
    isNormalUser = true;
    description = "deadmade";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      #kdePackages.kate
      #  thunderbird
    ];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = false;
  services.displayManager.autoLogin.user = "deadmade";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    tuigreet
    inputs.neovim-config.packages.${pkgs.stdenv.hostPlatform.system}.nvim
    inputs.chiplang-nix.packages.${pkgs.stdenv.hostPlatform.system}.depthfinder
    pkgs.unstable.vlc
    pkgs.unstable.telegram-desktop
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "deadmade";
        command = "${pkgs.tuigreet}/bin/tuigreet 
        --issue 
        --theme border=magenta;text=cyan;prompt=green;time=red;action=blue;button=yellow;container=black;input=red
        --cmd Hyprland"; # start Hyprland with a TUI login manager
      };
    };
  };

  hardware = {
    graphics.enable = true;
    nvidia = {
      open = false;
      powerManagement.enable = true;
    };
    logitech.wireless = {
      enable = true;
    };
  };

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

# Mainboard hardware control for the MSI MEG X570 ACE (MS-7C35).
# Host-specific: sensor monitoring, fan-curve control, and RGB (Mystic Light).
{pkgs, ...}: {
  # --- Sensors -------------------------------------------------------------
  # The X570 ACE uses a Nuvoton NCT679x super-I/O chip for temps/fans/voltages.
  # Loading nct6775 exposes it under /sys/class/hwmon for the tools below.
  # After a rebuild, run `sudo sensors-detect` once, then `sensors`.
  boot.kernelModules = ["nct6775"];

  # --- Fan control + monitoring -------------------------------------------
  # CoolerControl: daemon + GUI for custom fan curves driven by hwmon temps.
  # Also surfaces all sensor readings, so it doubles as the monitor.
  programs.coolercontrol.enable = true;

  # --- RGB lighting --------------------------------------------------------
  # OpenRGB controls Mystic Light over SMBus; the service loads i2c-dev.
  # MSI X570 coverage varies — if devices don't appear, check
  # `openrgb --list-devices` and try a newer package.
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  environment.systemPackages = with pkgs; [
    lm_sensors
  ];
}

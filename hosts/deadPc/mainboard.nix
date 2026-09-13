{pkgs, ...}: {
  boot.kernelModules = ["nct6775"];

  programs.coolercontrol.enable = true;

  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  environment.systemPackages = with pkgs; [
    lm_sensors
  ];
}

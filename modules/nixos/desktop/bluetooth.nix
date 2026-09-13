{pkgs, ...}: {
  hardware.bluetooth.enable = true;
  hardware.bluetooth = {
    settings = {
      General = {
        Experimental = true;
        Enable = "Source,Sink,Media,Socket";
      };
    };
    powerOnBoot = true;
  };

  environment.systemPackages = with pkgs; [
  ];

  services.blueman.enable = true;
}

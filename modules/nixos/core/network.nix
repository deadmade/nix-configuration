{lib, ...}: {
  networking = lib.mkDefault {
    networkmanager.enable = true;

    firewall = {
      enable = true;
    };

    useDHCP = false;
    dhcpcd.enable = false;
    nameservers = [];
  };
}

{lib, ...}: {
  networking = lib.mkDefault {
    networkmanager.enable = true;
    #   networkmanager.unmanaged = [
    #     "*"
    #     "except:type:wwan"
    #     "except:type:gsm"
    #   ];
    firewall = {
      enable = true;
      #     allowedTCPPorts = [
      #       22
      #       80
      #       443
      #       59010
      #       59011
      #       8080
      #     ];
      #     allowedUDPPorts = [
      #       59010
      #       59011
      #     ];
    };

    useDHCP = false;
    dhcpcd.enable = false;

    nameservers = [
      #"1.1.1.1"
      #"2606:4700:4700::1111"
    ];
  };
}

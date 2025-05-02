{
  pkgs,
  host,
  options,
  lib,
  ...
}: {
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
  };

  programs.nm-applet = {
    enable = true;
  };
}

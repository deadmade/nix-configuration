{
  deadConvertible = {
    system = "x86_64-linux";
    nixosModules = [
      ./deadConvertible/config.nix
    ];
    homeModule = ./deadConvertible/home.nix;
    enableHome = true;
  };

  deadPc = {
    system = "x86_64-linux";
    nixosModules = [
      ./deadPc/config.nix
    ];
    homeModule = ./deadPc/home.nix;
    enableHome = true;
  };

  deadWsl = {
    system = "x86_64-linux";
    nixosModules = [
      ./deadWsl/config.nix
    ];
    homeModule = ./deadWsl/home.nix;
    enableHome = true;
  };

  deadPi = {
    system = "aarch64-linux";
    nixosModules = [
      ./deadPi
    ];
    enableHome = false;
    useSdImageInstaller = true;
    extraNixosModules = [
      {
        sdImage.compressImage = false;
      }
    ];
  };
}

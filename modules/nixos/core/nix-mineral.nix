{inputs, ...}: {
  imports = [inputs.nix-mineral.nixosModules.nix-mineral];

  nix-mineral = {
    enable = true;

    preset = "compatibility";

    settings = {
      debug = {
        debugfs = true;

        panic-reboot = false;

        coredump = true;
      };

      etc = {
        kicksecure-gitconfig = false;
      };

      kernel = {
        binfmt-misc = true;

        cpu-mitigations = "smt-on";

        slab-debug = false;

        perf-subsystem.restrict-usage = false;

        perf-subsystem.restrict-access = false;
      };

      network = {
        random-mac = false;
      };

      system = {
        multilib = true;
      };
    };
  };
}

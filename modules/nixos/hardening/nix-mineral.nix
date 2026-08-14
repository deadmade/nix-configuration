{inputs, ...}: {
  imports = [inputs.nix-mineral.nixosModules.nix-mineral];

  nix-mineral = {
    enable = true;

    # Undoes the desktop-hostile defaults: noexec on /home, /tmp and /var/lib;
    # hidepid on /proc; binfmt_misc off; ptrace_scope=3; multilib off.
    # These are exactly the breakages that sank the 2026-08-01 attempt.
    preset = "compatibility";

    settings = {
      debug = {
        # Default false sets debugfs=off, unmounting /sys/kernel/debug.
        # tracefs still mounts separately so bpftrace mostly survives, but
        # bcc tools and some perf paths need debugfs. Profiling/eBPF tooling
        # is a stated requirement for this host.
        debugfs = true;

        # Default true sets panic=-1, rebooting instantly on kernel panic.
        # Combined with quiet-boot that turns a failed boot into a silent
        # reboot loop with no readable message. A frozen screen is
        # diagnosable; a silent loop is not.
        panic-reboot = false;

        # Default false sets kernel.core_pattern=|/bin/false, fs.suid_dumpable=0,
        # a PAM *hard* `core 0` limit, and disables systemd-coredump storage.
        # The hard PAM limit means `ulimit -c unlimited` can't recover it,
        # making post-mortem `gdb ./prog core` impossible. Debuggers and
        # profilers must not be further restricted on this host.
        coredump = true;
      };

      etc = {
        # Default true writes /etc/gitconfig with core.symlinks=false and
        # transfer/fetch/receive.fsckobjects=true. nixpkgs' git reads that
        # file and modules/home-manager/core/git.nix doesn't override it, so
        # `git clone` of any repo containing symlinks would silently write
        # them out as plain text files holding the target path, and cloning
        # a repo with malformed historical objects would hard-fail.
        kicksecure-gitconfig = false;
      };

      kernel = {
        # boot.binfmt.emulatedSystems on this host is dead without it.
        binfmt-misc = true;

        # Default "smt-off" would take this box from 24 threads to 12.
        cpu-mitigations = "smt-on";

        # Defaults true on kernels >= 6.17 (this host runs 7.1.8) and adds
        # allocator overhead to every build.
        slab-debug = false;

        # perf_event_max_sample_rate=1 and perf_cpu_time_max_percent=1 throttle
        # perf into uselessness, even as root.
        perf-subsystem.restrict-usage = false;

        # Keep the current perf_event_paranoid=2 rather than raising it to 3.
        perf-subsystem.restrict-access = false;
      };

      network = {
        # Default true randomizes networking.networkmanager.ethernet.macAddress.
        # This is a desktop on a fixed LAN, not a laptop roaming hostile
        # networks: randomizing breaks the router's DHCP reservation/static
        # lease on the next reconnect and stops Wake-on-LAN from working.
        random-mac = false;
      };

      system = {
        # Default false sets ia32_emulation=0, killing 32-bit applications.
        # This host needs them: desktop/base.nix sets
        # services.pipewire.alsa.support32Bit, and 32-bit Wine needs
        # hardware.graphics.enable32Bit. The compatibility preset sets this
        # too; stated explicitly because this is the regression that forced
        # the old alsa.support32Bit mkForce hack.
        multilib = true;
      };
    };
  };
}

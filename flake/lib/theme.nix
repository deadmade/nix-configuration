# Shared Stylix base for the NixOS module and the standalone Home Manager module.
#
# homeConfigurations here are standalone (flake.homeConfigurations), so Stylix's
# homeManagerIntegration.followSystem never applies and the theme has to be
# declared on both sides. Rather than hand-syncing two copies -- which had already
# drifted -- both import this.
#
# Note on colours: Noctalia owns the runtime palette (theme.source = "wallpaper"),
# so base16Scheme is now only the build-time fallback for the handful of targets
# Noctalia cannot template. Fonts and cursor remain genuinely Stylix's job.
{pkgs}: {
  polarity = "dark";

  # Catppuccin Mocha, deliberately, for the ~8 apps Noctalia cannot template.
  #
  # Deriving this from the wallpaper instead was TRIED and rejected on evidence.
  # stylix/palette.nix:125-131 does make base16Scheme default to a palette
  # generated from stylix.image, so the mechanism works -- but Stylix's generator
  # picks dominant image colours and assigns them to base16 slots without regard
  # for what those slots MEAN. Measured on this wallpaper set:
  #
  #   misty-boat.jpg   red #968da2  green #968e9d  -> RGB distance 5.1
  #   Cloudsnight.jpg  closest accent pair          -> RGB distance 15.9,
  #                    and it put blue in the red slot and red in the blue slot
  #
  # Under ~40 is effectively indistinguishable, so git diff +/- lines, syntax
  # highlighting and error-vs-success text would all collapse to one wash.
  # Noctalia's `vibrant` generator boosts chroma and keeps its roles semantic;
  # Stylix's does neither. A hand-tuned scheme is the right tool here.
  base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

  # Still set (the wallpaper Noctalia pins), because several Stylix targets use
  # the image itself rather than the palette.
  image = ../../wallpapers/misty-boat.jpg;

  opacity = {
    terminal = 0.8;
    desktop = 0.0;
  };

  cursor = {
    package = pkgs.unstable.bibata-cursors;
    # Bibata ships 16/20/22/24/28/32/...; 25 was not a size it builds, so the
    # cursor was being scaled from the nearest match.
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  fonts = {
    monospace = {
      package = pkgs.unstable.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font Mono";
    };

    # Montserrat is a geometric display face: wide, weak hinting at UI sizes, and
    # it was resolving for BOTH sans-serif and serif. Adwaita Sans is designed for
    # interface text, has a large x-height at 10-12pt and ships tabular figures,
    # which is what a bar clock and sysmon readouts need to stop shifting width.
    sansSerif = {
      package = pkgs.adwaita-fonts;
      name = "Adwaita Sans";
    };

    serif = {
      package = pkgs.source-serif-pro;
      name = "Source Serif Pro";
    };

    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };

    # There was no sizes block at all before, so everything ran on Stylix
    # defaults. Adwaita Sans reads larger than Montserrat at the same point size,
    # so applications drops a point to keep the same optical size at 1080p/scale 1.
    sizes = {
      applications = 11;
      desktop = 10;
      popups = 10;
      terminal = 12;
    };
  };
}

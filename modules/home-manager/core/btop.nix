{lib, ...}: {
  # Install & Configure btop
  programs.btop = {
    enable = true;
    settings = {
      vim_keys = true;

      # Noctalia's btop template renders ~/.config/btop/themes/noctalia.theme and
      # its apply.sh greps for `^color_theme\s*=\s*"noctalia"` before rewriting
      # btop.conf. Home Manager owns that file as a read-only store symlink, so
      # pre-seeding the name is what keeps the template's post-hook from dying.
      # Stylix keeps writing themes/stylix.theme alongside it; they coexist.
      color_theme = lib.mkForce "noctalia";
    };
  };
}

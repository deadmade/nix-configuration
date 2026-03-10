{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    (pkgs.symlinkJoin {
      name = "rustdesk";
      paths = [pkgs.unstable.rustdesk-flutter];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/rustdesk \
          --set XDG_CURRENT_DESKTOP Hyprland \
          --set RUSTDESK_ENABLE_WAYLAND 0 \
          --set GDK_BACKEND x11
      '';
    })
    pkgs.libei
    pkgs.libportal
  ];
}

{outputs, ...}: {
  imports = [
    outputs.homeManagerProfiles.desktopDev
    outputs.homeManagerModules.socialMedia.vencord
    outputs.homeManagerModules.socialMedia.freetube
    outputs.homeManagerModules.gaming
  ];
}

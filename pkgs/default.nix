{pkgs}: {
  ai-usagebar = pkgs.callPackage ./ai-usagebar {};
  helium = pkgs.callPackage ./helium {};
  claude-science = pkgs.callPackage ./claude-science {};
}

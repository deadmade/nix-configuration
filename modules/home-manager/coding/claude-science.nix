# claude-science. Vendored in ../../../pkgs/claude-science and exposed as
# pkgs.claude-science via the `additions` overlay. Run `claude-science serve`
# to start the daemon and open the web UI; state lives in ~/.claude-science.
{pkgs, ...}: {
  home.packages = [
    pkgs.claude-science
  ];
}

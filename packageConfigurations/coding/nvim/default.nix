{inputs, ...}: {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim

    ./plugins.nix
    ./config.nix
    ./lsp.nix
  ];

  programs.nixvim.enable = true;
}

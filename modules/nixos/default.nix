 {
  imports = [
    ./packages.nix 
    #(import ./user.nix { inherit pkgs; }) # Uncomment if you need to import user.nix
  ];
}

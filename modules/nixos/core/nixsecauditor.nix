{inputs, ...}: {
  imports = [inputs.nixsecauditor.nixosModules.default];

  security.nixsecauditor.enable = true;
}

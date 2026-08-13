{inputs, ...}: {
  imports = [inputs.nixsecauditor.nixosModules.default];

  # Eval-time static security audit: findings surface as warnings on rebuild.
  # Full reports: security.nixsecauditor.report.outPackages.{json,markdown}
  security.nixsecauditor.enable = true;
}

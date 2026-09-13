{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    claude-code
    ccstatusline
    antigravity-cli

    tuicr
    grok
  ];
}

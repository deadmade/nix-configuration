{
  pkgs,
  inputs,
  ...
}: {
  imports = [
  ];

  environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    claude-code
    opencode
    gemini-cli
    #nanocoder
  ];
}

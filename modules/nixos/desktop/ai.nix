{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    #opencode
    claude-code
    antigravity-cli
    #coderabbit-cli
    codex
    tuicr
    #hermes-agent
  ];
}

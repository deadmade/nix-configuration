{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    #claude-code
    #opencode
    claude-code
    #gemini-cli
    #coderabbit-cli
    codex
    tuicr
    #hermes-agent
  ];
}

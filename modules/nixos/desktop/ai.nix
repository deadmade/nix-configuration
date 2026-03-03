{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    claude-code
    opencode
    gemini-cli
    copilot-cli
    coderabbit-cli
    codex
    tuicr
  ];
}

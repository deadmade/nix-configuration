{
  pkgs,
  inputs,
  ...
}: {
  imports = [
  ];

  environment.systemPackages = with inputs.llm-agents.packages.${pkgs.system}; [
    claude-code
    opencode
  ];
}

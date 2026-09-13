{
  config,
  pkgs,
  ...
}: let
  renderedConfig = "${config.xdg.stateHome}/starship/starship.toml";

  promptTemplate = pkgs.runCommand "starship.toml.tmpl" {} ''
    sed "s/^palette = 'catppuccin_mocha'/palette = 'noctalia'/" ${./starship.toml} > $out
    cat ${./noctalia-palette.tmpl} >> $out
  '';
in {
  _module.args.starshipPromptTemplate = promptTemplate;
  _module.args.starshipRenderedConfig = renderedConfig;

  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    configPath = renderedConfig;
  };
}

{
  config,
  pkgs,
  ...
}: let
  # Where Noctalia renders the prompt. Deliberately NOT under ~/.config: home-manager
  # owns that path as a read-only store symlink, which is exactly why Noctalia's
  # builtin `starship` template cannot be used -- its apply.sh does
  # `cat "$tmp" > "$STARSHIP_CONFIG"` and dies with EACCES on the symlink.
  renderedConfig = "${config.xdg.stateHome}/starship/starship.toml";

  # The prompt layout stays in this repo; only the palette is substituted. Built
  # by concatenation so there is exactly one copy of the layout to maintain.
  promptTemplate = pkgs.runCommand "starship.toml.tmpl" {} ''
    sed "s/^palette = 'catppuccin_mocha'/palette = 'noctalia'/" ${./starship.toml} > $out
    cat ${./noctalia-palette.tmpl} >> $out
  '';
in {
  # Exported for the Noctalia user-template entry in the hyprland module.
  _module.args.starshipPromptTemplate = promptTemplate;
  _module.args.starshipRenderedConfig = renderedConfig;

  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    # `settings` is deliberately unset. home-manager gates the config file write
    # on `hasGeneratedConfig = settings != {} || presets != []` but exports
    # STARSHIP_CONFIG unconditionally (modules/programs/starship.nix:139,141) --
    # so leaving it empty gives the env var pointing at a path home-manager does
    # not own, which is precisely the seam Noctalia needs to write into.
    # The layout lives in ./starship.toml and reaches starship via the template.
    configPath = renderedConfig;
  };
}

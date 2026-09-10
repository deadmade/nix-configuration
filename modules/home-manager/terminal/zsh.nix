{pkgs, ...}: {
  programs.bat = {
    enable = true;
    # Noctalia's bat template renders themes/noctalia.tmTheme from the wallpaper.
    # Its apply.sh would normally select the theme AND run `bat cache --build`
    # itself, but it opens with `touch ~/.config/bat/config` -- which Home
    # Manager owns as a root-owned 444 store symlink -- so it dies EACCES before
    # reaching either. (Confirmed in the journal: "touch: cannot touch ...:
    # Permission denied".) The pre-seed trick that works for ghostty and hyprland
    # does NOT help, because the touch happens before any grep.
    #
    # So we do both halves ourselves: name the theme here, and run the cache
    # rebuild from noctalia's colors_changed hook, which fires AFTER templates
    # render (application_services.cpp:642-647).
    config.theme = "noctalia";
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    # Colours come from Noctalia's fzf template now, not Stylix -- the Stylix
    # fzf target is switched off in core/stylix.nix so there is exactly one
    # writer. That template has no post-hook and nothing sources its output on
    # its own, so the `source` line in initContent below is what actually makes
    # it apply.
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    history = {
      size = 10000;
      save = 10000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
      extended = true;
    };

    syntaxHighlighting.highlighters = [
      "main"
      "brackets"
      "pattern"
      "root"
      "line"
    ];

    shellAliases = {
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
      cat = "bat";
    };

    # Sources the fzf palette Noctalia renders from the wallpaper. Guarded so it
    # is safe before the first render, and placed via initContent (not the
    # deprecated initExtra) so it lands after fzf's own zsh integration.
    initContent = ''
      [[ -f ~/.config/fzf/themes/noctalia.sh ]] && source ~/.config/fzf/themes/noctalia.sh
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "gitfast"
        "dotnet"
        "sudo"
        "dirhistory"
        "history"
        "colored-man-pages"
        "extract"
        "fzf"
      ];
    };
  };

  home.packages = with pkgs; [
  ];
}

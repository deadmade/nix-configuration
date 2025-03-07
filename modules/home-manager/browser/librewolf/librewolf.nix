{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    inputs.textfox.homeManagerModules.default
  ];

  programs.librewolf = {
    enable = true;
    package = pkgs.unstable.librewolf-wayland;
    languagePacks = ["de" "en-US"];

    policies = {
    };

    profiles.Default = {
      extensions = with inputs.firefox-addons.packages."x86_64-linux"; [
        ublock-origin
        darkreader
        consent-o-matic
        #gesturefy
        vimium
        proton-pass
        sponsorblock
        clearurls
        sponsorblock
      ];

      search.engines = {
        "Nix Packages" = {
          urls = [
            {
              template = "https://search.nixos.org/packages";
              params = [
                {
                  name = "type";
                  value = "packages";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];

          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = ["@np"];
        };

        "Home Manager" = {
          urls = [
            {
              template = "https://home-manager-options.extranix.com";
              params = [
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];

          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = ["@hm"];
        };

        "Searx" = {
          urls = [
            {
              template = "https://paulgo.io/search";
              params = [
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];

          iconUpdateURL = "https://paulgo.io/favicon.ico";
          definedAliases = ["@sx"];
        };

        "Amazon" = {
          urls = [
            {
              template = "https://www.amazon.de/s";
              params = [
                {
                  name = "k";
                  value = "{searchTerms}";
                }
              ];
            }
          ];

          iconUpdateURL = "https://amazon.de/favicon.ico";
          definedAliases = ["@a"];
        };

        "YouTube" = {
          urls = [
            {
              template = "https://efy.piped.pages.dev/results";
              params = [
                {
                  name = "search_query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];

          iconUpdateURL = "https://piped.video/favicon.ico";
          definedAliases = ["yt"];
        };
      };
      search = {
        force = true;
        default = "DuckDuckGo";
        privateDefault = "DuckDuckGo";
      };

      settings = {
        "privacy.clearOnShutdown_v2.cookiesAndStorage" = false; # Disable cookie clearing
        "browser.urlbar.keepPanelOpenDuringImeComposition" = true; # Improve Firefox IME support
        "media.eme.enabled" = true; # Enable DRM for e.g. Spotify
        "privacy.resistFingerprinting.autoDeclineNoUserInputCanvasPrompts" = true; # Automatically decline Canvas request
        "dom.security.https_only_mode" = true;
        "browser.download.panel.shown" = false;
        "browser.toolbars.bookmarks.visibility" = "always";
        "signon.rememberSignons" = false;
        "browser.formfill.enable" = false;
        "signon.prefillForms" = false;
        "browser.shell.checkDefaultBrowser" = false;
      };
    };
  };

  textfox = {
    enable = true;
    profile = "Default";
    config = {
      background = {
        color = "#123456";
      };
      border = {
        color = "#654321";
        width = "4px";
        transition = "1.0s ease";
        radius = "3px";
      };
      displayWindowControls = true;
      displayNavButtons = false;
      displayUrlbarIcons = true;
      displaySidebarTools = false;
      displayTitles = false;
      font = {
        family = "Fira Code";
        size = "15px";
        accent = "#654321";
      };
      tabs.vertical = {
        margin = "1.0rem";
      };
      tabs.horizontal = {
        enable = false;
      };
    };
  };
}

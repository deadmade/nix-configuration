{
  inputs,
  pkgs,
  ...
}: {
  imports = [
  ];

  programs.librewolf = {
    enable = true;
    package = pkgs.librewolf;
    languagePacks = ["de" "en-US"];

    policies = {
      AppAutoUpdate = false;
      Bookmarks = false;
      DisableFirefoxAccounts = false;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisablePrivateBrowsing = true;
      DisableProfileImport = true;
      DisableSafeMode = true;
      DisableTelemetry = true;
      DisplayBookmarksToolbar = "never";
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      InstallAddonsPermission = "Allow";
      OfferToSaveLogins = false;
    };

    profiles.Default = {
      extensions.packages = with inputs.firefox-addons.packages."x86_64-linux"; [
        ublock-origin
        darkreader
        consent-o-matic
        #gesturefy
        proton-pass
        sponsorblock
        skip-redirect
        return-youtube-dislikes
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

          icon = "https://paulgo.io/favicon.ico";
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

          icon = "https://amazon.de/favicon.ico";
          definedAliases = ["@a"];
        };

        "youtube" = {
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

          icon = "https://piped.video/favicon.ico";
          definedAliases = ["yt"];
        };
      };
      search = {
        force = true;
        default = "ddg"; # DuckDuckGo
        privateDefault = "ddg"; #DuckDuckGo
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
        "identity.fxaccounts.enabled" = true;
        "privacy.resistFingerprinting.letterboxing" = true;
        "network.http.referer.XOriginPolicy" = 2;
        "webgl.disabled" = true;
      };
    };
  };
}

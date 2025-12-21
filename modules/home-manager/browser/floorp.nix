{
  inputs,
  pkgs,
  ...
}: {
  programs.floorp = {
    enable = true;
    package = pkgs.unstable.floorp-bin;
    languagePacks = ["de" "en-US"];

    policies = {
      AppAutoUpdate = false;
      Bookmarks = false;
      DisableFirefoxAccounts = true;
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
      extensions = with inputs.firefox-addons.packages."x86_64-linux"; [
        ublock-origin
        darkreader
        consent-o-matic
        gesturefy
        vimium
        proton-pass
        sponsorblock
        clearurls
        privacy-badger
        sponsorblock
        df-youtube
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
        # Settings for tabsleep, good for memory optimization
        "floorp.tabsleep.enabled" = true;
        "floorp.tabsleep.tabTimeoutMinutes" = 30;

        # Setting for ui browser
        "floorp.chrome.theme.mode" = 1;

        # Handle the vertical tabs
        "floorp.browser.sidebar.is.displayed" = false;
        "floorp.browser.tabbar.settings" = 2;
        "floorp.browser.tabs.verticaltab" = true;
        "floorp.enable.auto.restart" = true;
        "floorp.tabbar.style" = 2;

        # Disabling sidebar for now, I don't see the benefit
        "floorp.browser.sidebar.enable" = false;

        # # # Bookmark related settings
        #      "floorp.bookmarks.bar.focus.mode" = false;

        # Makes some website dark
        "layout.css.prefers-color-scheme.content-override" = 0;

        # Prevents the alt/command key from showing the menu bar. Gets annoying at time.
        "ui.key.menuAccessKeyFocuses" = false;

        # fonts
        "browser.display.use_document_fonts" = 1;
        "font.default.x-western" = "sans-serif";
        "font.size.variable.x-western" = 16;
        "font.name.monospace.x-western" = "ComicShannsMono Nerd Font Mono";
        "font.name.sans-serif.x-western" = "ComicShannsMono Nerd Font Propo";
        "font.name.serif.x-western" = "ComicShannsMono Nerd Font Propo";

        "app.update.auto" = false;
        "dom.image-lazy-loading.enabled" = true;
        "general.smoothScroll" = true;
        "media.autoplay.default" = 1;
        "browser.urlbar.placeholderName" = "search for something man";
        "browser.urlbar.update1" = true;
        "extensions.pocket.enable" = false;
        "extensions.pocket.showHome" = false;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.socialtracking.annotate.enabled" = true;
      };
    };
  };
}

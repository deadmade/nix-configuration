{
  inputs,
  pkgs,
  ...
}: {
  programs.firefox = {
    enable = false;

    profiles.Default = {
      extensions = with inputs.firefox-addons.packages."x86_64-linux"; [
        ublock-origin
        darkreader
        tabliss
        consent-o-matic
        gesturefy
        vimium
        proton-pass
        sponsorblock
        sidebery
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
      };
    };
  };

  inputs.textfox = {
    enable = true;
    profile = "Default";
    config = {
      # Optional config
    };
  };
}

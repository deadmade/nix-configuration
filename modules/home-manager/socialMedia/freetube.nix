{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.freetube-nix.homeManagerModules.default
  ];

  programs.freetube = {
    enable = true;
    package = pkgs.unstable.freetube;

    settings = {
      # --- Video / Playback -------------------------------------------------------
      allowDashAv1Formats = true; # bool
      defaultQuality = "1080"; # "144"|"240"|"360"|"480"|"720"|"1080"|"1440"|"2160"|"4320"|"auto"
      playNextVideo = false; # bool
      thumbnailPreference = "default"; # "default"|"start"|"end"
      blurThumbnails = false; # bool

      # --- Backend ----------------------------------------------------------------
      backendPreference = "local"; # "local"|"invidious"
      backendFallback = true; # bool

      # --- Appearance -------------------------------------------------------------
      baseTheme = "catppuccinMocha";
      # "dark"|"light"|"black"|"dracula"
      # "catppuccinMocha"|"catppuccinMacchiato"|"catppuccinFrappe"|"catppuccinLatte"
      # "hotPink"|"pastelPink"|"nordic"|"solarizedDark"|"solarizedLight"
      listType = "list"; # "list"|"grid"
      currentLocale = "us-US"; # "xx" or "xx-XX"
      landingPage = "subscribedchannels";
      # "subscriptions"|"subscribedchannels"|"trending"
      # "popular"|"playlists"|"history"|"settings"
      settingsSectionSortEnabled = true; # bool

      bounds = {
        x = 0;
        y = 0;
        width = 960;
        height = 1050;
        maximized = true;
        fullScreen = false;
      };

      # --- Privacy / History ------------------------------------------------------
      saveHistory = true; # bool
      checkForUpdates = false; # bool
      useRssFeeds = true; # bool
      region = "US"; # two-letter ISO 3166-1 alpha-2 code

      # --- SponsorBlock -----------------------------------------------------------
      # Actions: "skip"|"mute"|"autoSkip"|"doNothing"|"showIcon"
      useSponsorBlock = true;
      sponsorBlockSponsor = "skip";
      sponsorBlockSelfPromo = "skip";
      sponsorBlockInteraction = "skip";
      sponsorBlockIntro = "skip";
      sponsorBlockOutro = "skip";
      sponsorBlockPreview = "skip";
      sponsorBlockMusicOffTopic = "skip";

      # --- DeArrow ----------------------------------------------------------------
      useDeArrowTitles = false; # bool
      useDeArrowThumbnails = false; # bool

      # --- Hide / Distraction-free ------------------------------------------------
      hideVideoViews = false;
      hideChannelSubscriptions = false;
      hideSharingActions = false;
      hideWatchedSubs = false;
      hideLiveStreams = false;
      hideUpcomingPremieres = false;
      showDistractionFreeTitles = false;
      hideTrendingVideos = false;
      hidePopularVideos = false;
      hidePlaylists = false;
      hideActiveSubscriptions = false;
      hideSubscriptionsVideos = false;
      hideSubscriptionsShorts = false;
      hideSubscriptionsCommunity = false;
      hideChannelHome = true;
      hideChannelShorts = true;
      hideChannelPlaylists = true;
      hideChannelPodcasts = true;
      hideChannelCourses = true;
      hideChannelReleases = true;
      hideChannelCommunity = true;
      hideFeaturedChannels = true;
      hideVideoLikesAndDislikes = false;
      hideChapters = true;
      hideVideoDescription = false;
      hideCommentLikes = true;
      hideCommentPhotos = true;
      hideComments = false;
      hideRecommendedVideos = false;
      hideLiveChat = true;

      # --- Behaviour --------------------------------------------------------------
      generalAutoLoadMorePaginatedItemsEnabled = true;
      openDeepLinksInNewWindow = true;
      hideToTrayOnMinimize = true;
      unsubscriptionPopupStatus = true;
      onlyShowLatestFromChannel = true;
      onlyShowLatestFromChannelNumber = 16; # positive int
    };

    profiles = [
      {
        _id = "allChannels";
        name = "All Channels";
        bgColor = "#cba6f7";
        textColor = "#1e1e2e";
        subscriptions = [
          {
            handle = "@Bokoen1";
            name = "Bokoen1";
          }
          {
            handle = "@Bohndesliga";
            name = "Bohndesliga";
          }
          {
            handle = "@t3dotgg";
            name = "Theo - t3.gg";
          }
          {
            handle = "@ManuThiele";
            name = "Manu Thiele";
          }
          {
            handle = "@BelYves";
            name = "BelYves";
          } # verify
          {
            handle = "@BeHaind";
            name = "BeHaind";
          } # verify
          {
            handle = "@BrodieRobertson";
            name = "Brodie Robertson";
          }
          {
            handle = "@AtBroski";
            name = "At Broski - Die Sport Show";
          } # verify
          {
            handle = "@der8auer";
            name = "der8auer";
          }
          {
            handle = "@ZipTieTech";
            name = "Zip Tie Tech";
          } # verify
          {
            handle = "@LowLevelTV";
            name = "Low Level";
          }
          {
            handle = "@ThePrimeTimeagen";
            name = "The PrimeTime";
          } # verify
          {
            handle = "@HitOderShit";
            name = "Hit oder Shit";
          } # verify
          {
            handle = "@ForrestKnight";
            name = "ForrestKnight";
          }
          {
            handle = "@ChrisTitusTech";
            name = "Chris Titus Tech";
          }
          {
            handle = "@davidbombal";
            name = "David Bombal";
          }
          {
            handle = "@KaiLentit";
            name = "Kai Lentit";
          } # verify
          {
            handle = "@Simplicissimus";
            name = "Simplicissimus";
          }
          {
            handle = "@DavesGarage";
            name = "Dave's Garage";
          }
          {
            handle = "@GeldfuerDieWelt";
            name = "Geld für die Welt — Maurice Höfgen";
          } # verify
          {
            handle = "@Fireship";
            name = "Fireship";
          }
          {
            handle = "@NDC";
            name = "NDC Conferences";
          }
          {
            handle = "@DistroTube";
            name = "DistroTube";
          }
          {
            handle = "@bigboxSWE";
            name = "bigboxSWE";
          }
          {
            handle = "@WasKostetDieWelt";
            name = "Was kostet die Welt?";
          } # verify
          {
            handle = "@WelchLabs";
            name = "Welch Labs";
          }
          {
            handle = "@CalcioBerlin";
            name = "CALCIO BERLIN";
          }
          {
            handle = "@AltF4Games";
            name = "AltF4Games";
          }
          {
            handle = "@ZipTieTuning";
            name = "Zip Tie Tuning";
          } # verify
          {
            handle = "@TheStandupPod";
            name = "TheStandupPod";
          } # verify
          {
            handle = "@AltRepo";
            name = "AltRepo";
          } # verify
          {
            handle = "@EmilyYoung";
            name = "Emily Young";
          } # verify
          {
            handle = "@DevDetour";
            name = "Dev Detour";
          } # verify
          {
            handle = "@Codeolences";
            name = "Codeolences";
          } # verify
          {
            handle = "@beyondfireship";
            name = "Beyond Fireship";
          }
          {
            handle = "@MarcoCodes";
            name = "Marco Codes";
          }
          {
            handle = "@TinyTechnicalTutorials";
            name = "Tiny Technical Tutorials";
          }
          {
            handle = "@teej_dv";
            name = "TJ DeVries";
          }
          {
            handle = "@MapleCircuit";
            name = "Maple Circuit";
          } # verify
          {
            handle = "@CodeAestheticMalloc";
            name = "Malloc";
          } # verify
          {
            handle = "@CodeAesthetic";
            name = "CodeAesthetic";
          }
          {
            handle = "@ULabs";
            name = "U-Labs";
          } # verify
          {
            handle = "@MindTheMap";
            name = "Mind The Map";
          } # verify
          {
            handle = "@developersclub";
            name = "developers club";
          } # verify
          {
            handle = "@Scoops-BI";
            name = "Scoops";
          } # verify
          {
            handle = "@AdamSomething";
            name = "Adam Something";
          }
          {
            handle = "@ColdFusion";
            name = "ColdFusion";
          }
          {
            handle = "@CodeBullet";
            name = "Code Bullet";
          }
          {
            handle = "@programmingwithmosh";
            name = "Programming with Mosh";
          }
          {
            handle = "@HapticRush";
            name = "HapticRush";
          } # verify
          {
            handle = "@SebastianLague";
            name = "Sebastian Lague";
          }
          {
            handle = "@Reducible";
            name = "Reducible";
          }
          {
            handle = "@BenEater";
            name = "Ben Eater";
          }
          {
            handle = "@awesomekling";
            name = "Andreas Kling";
          }
          {
            handle = "@jonhoo";
            name = "Jon Gjengset";
          }
          {
            handle = "@TsodingDaily";
            name = "Tsoding Daily";
          }
          {
            handle = "@NoBoilerplate";
            name = "No Boilerplate";
          }
          {
            handle = "@jherr";
            name = "Jack Herrington";
          }
          {
            handle = "@KevinPowell";
            name = "Kevin Powell";
          }
          {
            handle = "@ThePrimeagen";
            name = "ThePrimeagen";
          }
          {
            handle = "@dreamsofcode";
            name = "Dreams of Code";
          }
          {
            handle = "@Code-Guild";
            name = "Code Guild";
          }
        ];
      }
    ];
  };
}

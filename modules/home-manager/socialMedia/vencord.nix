{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixcord.homeModules.nixcord
  ];

  programs.nixcord = {
    discord.enable = false;
    enable = false;
    vesktop.enable = true;

    config = {
      frameless = true;
      transparent = true;
      notifyAboutUpdates = true;

      plugins = {
        unlockedAvatarZoom.enable = true;
        betterGifPicker.enable = true;
        betterRoleDot.enable = true;
        betterSettings.enable = true;
        betterUploadButton.enable = true;
        callTimer.enable = true;
        colorSighted.enable = true;
        disableCallIdle.enable = true;
        dontRoundMyTimestamps.enable = true;
        fakeNitro.enable = true;
        favoriteEmojiFirst.enable = true;
        favoriteGifSearch.enable = true;
        fixSpotifyEmbeds.enable = true;
        fixYoutubeEmbeds.enable = true;
        forceOwnerCrown.enable = true;
        friendsSince.enable = true;
        gameActivityToggle.enable = true;
        iLoveSpam.enable = true;
        imageZoom.enable = true;
        loadingQuotes.enable = true;
        memberCount.enable = true;
        mentionAvatars.enable = true;
        messageLatency.enable = true;
        noBlockedMessages.enable = true;
        noDevtoolsWarning.enable = true;
        noF1.enable = true;
        noProfileThemes.enable = true;
        noReplyMention.enable = true;
        noTypingAnimation.enable = true;
        permissionFreeWill.enable = true;
        petpet.enable = true;
        platformIndicators.enable = true;
        userMessagesPronouns.enable = true;
        readAllNotificationsButton.enable = true;
        relationshipNotifier.enable = true;
        roleColorEverywhere.enable = true;
        showHiddenChannels.enable = true;
        showHiddenThings.enable = true;
        silentTyping.enable = true;
        spotifyControls.enable = true;
        typingIndicator.enable = true;
        whoReacted.enable = true;
        youtubeAdblock.enable = true;
        anonymiseFileNames.enable = true;
        experiments.enable = true;
        fixCodeblockGap.enable = true;
        fixImagesQuality.enable = true;
        webScreenShareFixes.enable = true;
        viewIcons.enable = true;
        voiceMessages.enable = true;
        vencordToolbox.enable = true;
        validUser.enable = true;
        summaries.enable = true;
        showTimeoutDuration.enable = true;

        showMeYourName = {
          enable = true;
        };

        messageLogger = {
          enable = true;
          collapseDeleted = true;
        };

        betterFolders = {
          enable = true;
          closeAllFolders = true;
          closeAllHomeButton = true;
          closeOthers = true;
          forceOpen = true;
        };
      };
    };
  };
}

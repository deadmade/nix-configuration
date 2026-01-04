{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.solaar.nixosModules.default
  ];

  environment.systemPackages = with pkgs; [
    logiops
  ];

  services.solaar = {
    enable = true; # Enable the service
    package = pkgs.unstable.solaar; # The package to use
    window = "hide"; # Show the window on startup (show, *hide*, only [window only])
    batteryIcons = "regular"; # Which battery icons to use (*regular*, symbolic, solaar)
    extraArgs = ""; # Extra arguments to pass to solaar on startup
  };

  # Create systemd service
  # https://github.com/PixlOne/logiops/blob/5547f52cadd2322261b9fbdf445e954b49dfbe21/src/logid/logid.service.in
  systemd.services.logiops = {
    description = "Logitech Configuration Daemon";
    startLimitIntervalSec = 0;
    after = ["multi-user.target"];
    wantedBy = ["graphical.target"];
    wants = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.logiops}/bin/logid -v -c /etc/logid.cfg";
      User = "root";
    };
  };

  # Add a `udev` rule to restart `logiops` when the mouse is connected
  # https://github.com/PixlOne/logiops/issues/239#issuecomment-1044122412
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", ATTRS{manufacturer}=="Logitech", ATTRS{model_name}=="MX Master 3S", RUN{program}="${pkgs.systemd}/bin/systemctl --no-block try-restart logiops.service"
  '';

  # Configuration for logiops
  environment.etc."logid.cfg".text = ''
    devices: ({
        name: "MX Master 3S";
        dpi: 650;
        smartshift:
        {
            on: true;
            threshold: 5;
            torque: 8;
        };
        hiresscroll:
        {
            hires: false;
            invert: false;
            target: false;
        };
        thumbwheel:
        {
            divert: true;
            left: {
                mode: "OnInterval";
                interval: 3;
                direction: "Left";
                action =
                {
                    type: "Keypress";
                    keys: ["KEY_LEFT"];
                };
            },
            right: {
                mode: "OnInterval";
                interval: 3;
                direction: "Right";
                action =
                {
                    type: "Keypress";
                    keys: ["KEY_RIGHT"];
                };
            }
        }
        buttons: (
        {
            cid: 0xc3;
            action =
            {
                type: "Gestures";
                gestures: (
                {
                    direction: "Up";
                    mode: "OnRelease";
                    action =
                    {
                        type: "Keypress";
                        keys: ["KEY_VOLUMEUP"];
                   };
                },
                {
                    direction: "Down";
                    mode: "OnRelease";
                    action =
                    {
                        type: "Keypress";
                        keys: ["KEY_VOLUMEDOWN"];
                    };
                    },
                {
                    direction: "Left";
                    mode: "OnRelease";
                    action =
                    {
                        type: "Keypress";
                        keys: ["KEY_PREVIOUSSONG"];
                    }
                    },
                {
                    direction: "Right";
                    mode: "OnRelease";
                    action =
                    {
                        type: "Keypress";
                        keys: ["KEY_NEXTSONG"];
                    }
                    },
                {
                    direction: "None";
                    mode: "OnRelease";
                    action =
                    {
                        type: "Keypress";
                        keys: ["KEY_PLAYPAUSE"];
                    }
                });
            };
        },
        {
            cid: 0xc4;
            action =
            {
                type: "ToggleSmartshift";
            };
        },
        {
            cid: 0x56;
            action =
            {
                type: "Keypress";
                keys: ["KEY_FORWARD"]
            }
        },
        {
            cid: 0x53;
            action =
            {
                type: "Keypress";
                keys: ["KEY_BACK"]
            }
        });
    });
  '';
}

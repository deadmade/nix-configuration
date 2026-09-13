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
    enable = true;
    package = pkgs.unstable.solaar;
    window = "hide";
    batteryIcons = "regular";
    extraArgs = "";
  };

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

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", ATTRS{manufacturer}=="Logitech", ATTRS{model_name}=="MX Master 3S", RUN{program}="${pkgs.systemd}/bin/systemctl --no-block try-restart logiops.service"
  '';

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

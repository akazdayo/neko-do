{pkgs, ...}: let
  dataDir = "/var/lib/neko";
  envFile = "${dataDir}/neko.env";
  tcpPort = 8080;
  udpRange = "52000-52100";
in {
  # Nix
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Networking
  networking.hostName = "neko";
  networking.firewall.allowedTCPPorts = [22 tcpPort];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 52000;
      to = 52100;
    }
  ];

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Timezone
  time.timeZone = "Asia/Tokyo";

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    docker
  ];

  # Docker
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.neko = {
      autoStart = true;
      image = "ghcr.io/m1k1o/neko/firefox:latest";
      environment = {
        NEKO_DESKTOP_SCREEN = "1920x1080@30";
        NEKO_SESSION_FILE = "/var/lib/neko/sessions.json";
        NEKO_WEBRTC_EPR = udpRange;
        NEKO_WEBRTC_ICELITE = "1";
      };
      environmentFiles = [envFile];
      extraOptions = [
        "--pull=always"
        "--shm-size=2g"
      ];
      ports = [
        "${toString tcpPort}:8080/tcp"
        "${udpRange}:${udpRange}/udp"
      ];
      volumes = [
        "${dataDir}:/var/lib/neko"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0700 root root -"
  ];

  systemd.services.neko-secrets = {
    description = "Generate initial credentials for the Neko container";
    before = ["docker-neko.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0700 ${dataDir}

      if [ ! -s ${envFile} ]; then
        user_password="$(${pkgs.coreutils}/bin/tr -dc 'A-Za-z0-9' </dev/urandom | ${pkgs.coreutils}/bin/head -c 24)"
        admin_password="$(${pkgs.coreutils}/bin/tr -dc 'A-Za-z0-9' </dev/urandom | ${pkgs.coreutils}/bin/head -c 24)"

        {
          printf 'NEKO_MEMBER_MULTIUSER_USER_PASSWORD=%s\n' "$user_password"
          printf 'NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD=%s\n' "$admin_password"
        } >${envFile}

        chmod 0600 ${envFile}
      fi
    '';
  };

  systemd.services.docker-neko = {
    after = [
      "docker.service"
      "network-online.target"
      "neko-secrets.service"
    ];
    requires = [
      "docker.service"
      "neko-secrets.service"
    ];
    wants = ["network-online.target"];
  };

  # Swap
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 3 * 1024;
    }
  ];

  system.stateVersion = "26.05";
}

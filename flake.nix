{
  description = "A very basic flake";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils } :
  flake-utils.lib.eachDefaultSystem (system: 
  let
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.default = pkgs.buildGoModule {
        src = ./.;
        name = "tailscale-auth-proxy";
        vendorHash = "sha256-1hhztYJcTduwkm99cElsA9tp7hra8Tf8bQzPlh9zSvA";
    };
    apps.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/cmd";
    };
    nixosModules.tailscaleAuthProxy = { config, lib, ...}: {
      options.services.tailscaleAuthProxy = with lib; {
        enable = lib.mkEnableOption "enable tailscale auth proxy";
        upstream = lib.mkOption {
          type = types.str;
          default = "http://localhost:3000";
        };
        listenAddr = lib.mkOption {
          type = types.str;
          default = ":38388";
        };
      };
      config = lib.mkIf config.services.tailscaleAuthProxy.enable {
        systemd.services.tailscale-auth-proxy = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            User = "tailscaleap";
            Group = "tailscaleap";
            DynamicUsers = true;
            Restart = "always";
            ExecStart = "${self.packages."${system}".default}/bin/cmd";
          };
        };
      };
    };
  });
}

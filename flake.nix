{
  description = "A very basic flake";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.buildGoModule {
          src = ./.;
          name = "tailscale-auth-proxy";
          vendorHash = "sha256-1hhztYJcTduwkm99cElsA9tp7hra8Tf8bQzPlh9zSvA";
        };
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/cmd";
        };
        nixosModules.tailscaleAuthProxy = { config, lib, ... }: {
          options.services.tailscaleAuthProxy = with lib; {
            enable = lib.mkEnableOption "enable tailscale auth proxy";
            proxies = lib.mkOption {
              description = "List of upstream/downstream proxy configs";
              type = lib.types.attrsOf
                (lib.types.submodule
                  ({ config, ... }: {
                    options = {
                      bind = lib.mkOption
                        {
                          description = "bind address";
                          type = lib.types.str;
                        };
                      app = lib.mkOption
                        {
                          description = "app address";
                          type = lib.types.str;
                        };
                    };
                  }));
            };
            default = {
              grafana = {
                bind = ":38388";
                app = "localhost:3000";
              };
            };
          };
          config =
            lib.mkIf
              config.services.tailscaleAuthProxy.enable
              {
                # systemd.services.tailscale-auth-proxy = {
                #   wantedBy = [ "multi-user.target" ];
                #   serviceConfig = {
                #     User = "tailscaleap";
                #     Group = "tailscaleap";
                #     DynamicUser = true;
                #     Restart = "always";
                #     ExecStart = "${self.packages."${system}".default}/bin/cmd";
                #   };
                # };
                systemd.services = lib.attrsets.mapAttrs'
                  (name: value: {
                    name = "tailscale-auth-proxy@${name}";
                    value = {
                      wantedBy = [ "multi-user.target" ];
                      serviceConfig = {
                        User = "tailscaleap";
                        Group = "tailscaleap";
                        DynamicUser = true;
                        Restart = "always";
                        ExecStart = "${self.packages."${system}".default}/bin/cmd -listen ${value.bind} -upstream ${value.app}";
                      };
                    };
                  })
                  config.services.tailscaleAuthProxy.proxies;
              };
        };
      });
}

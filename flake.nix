{
  description = "A very basic flake";

  outputs = { self, nixpkgs} : let
    # Nixpkgs instantiated for supported system types.
    nixPkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    # System types to support.
    supportedSystems =
      [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    stdenv = nixPkgsFor.stdenv;
  in {

    #packages = forAllSystems (system:
    #  let
    #    pkgs = nixPkgsFor.${system};
    #    stdenv = pkgs.stdenv;
    #  in {
    #  tailscale-auth-proxy = pkgs.buildGoModule {
    #    src = ./.;
    #    name = "tailscale-auth-proxy";
    #    vendorHash = "sha256-1hhztYJcTduwkm99cElsA9tp7hra8Tf8bQzPlh9zSvA";
    #  };
    #  default = self.packages.${system}.tailscale-auth-proxy;
    #});
    packages.x86_64.default = pkgs.buildGoModule {
        src = ./.;
        name = "tailscale-auth-proxy";
        vendorHash = "sha256-1hhztYJcTduwkm99cElsA9tp7hra8Tf8bQzPlh9zSvA";
    };
    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/cmd";
      };
    });
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
            ExecStart = "${self.packages."${nixpkgs.system}".default}/bin/cmd";
          };
        };
      };
    };
  };
}

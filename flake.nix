{
  description = "Raj's Home manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs @ { self, nixpkgs, home-manager, nixpkgsUnstable, darwin, nix-homebrew, ... }: {
    homeConfigurations = {
      mbp = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-darwin";
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              direnv = prev.direnv.overrideAttrs (old: {
                env = (old.env or {}) // { CGO_ENABLED = "1"; };
              });
            })
          ];
        };
        modules = [ ./nixpkgs/home-manager/mbp.nix ];
        extraSpecialArgs = { pkgsUnstable = inputs.nixpkgsUnstable.legacyPackages.aarch64-darwin; };
      };

      server = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
        modules = [ ./nixpkgs/home-manager/server.nix ];
        extraSpecialArgs = { pkgsUnstable = inputs.nixpkgsUnstable.legacyPackages.x86_64-linux; };
      };
    };

    darwinConfigurations = {
      # nix build .#darwinConfigurations.mbp2021.system
      # ./result/sw/bin/darwin-rebuild switch --flake .
      mbp = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./nixpkgs/darwin/configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "rajrajhans";
              autoMigrate = true;
            };
          }
        ];
        inputs = { inherit darwin nixpkgs; };
      };
    };
  };
}

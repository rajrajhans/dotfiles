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

  outputs = inputs @ { self, nixpkgs, home-manager, nixpkgsUnstable, darwin, nix-homebrew, ... }:
    let
      # Carry a one-line patch against gitstatusd: pass force=1 to
      # git_index_read_ex so we always re-parse the index instead of trusting
      # libgit2's broken stat-based change detection. Without this, p10k's vcs
      # segment shows phantom staged/unstaged after `git commit` rewrites the
      # index from another process. See nixpkgs/patches/gitstatus-force-index-reload.patch.
      gitstatusOverlay = final: prev: {
        gitstatus = prev.gitstatus.overrideAttrs (old: {
          patches = (old.patches or []) ++ [
            ./nixpkgs/patches/gitstatus-force-index-reload.patch
          ];
        });
      };
    in {
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
            gitstatusOverlay
          ];
        };
        modules = [ ./nixpkgs/home-manager/mbp.nix ];
        extraSpecialArgs = { pkgsUnstable = inputs.nixpkgsUnstable.legacyPackages.aarch64-darwin; };
      };

      server = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [ gitstatusOverlay ];
        };
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
              enableRosetta = false;
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

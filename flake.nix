{
  description = "Darkmatter devshell - reusable Nix modules for development environments";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    darkmatter-agents.url = "github:darkmatter/agents";
    darkmatter-agents.inputs.agent-skills.inputs.nixpkgs.follows = "nixpkgs";
    darkmatter-agents.inputs.agent-skills.inputs.home-manager.follows = "home-manager";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      agenix,
      darkmatter-agents,
      flake-parts,
      self,
      ...
    }:
    let
      defaultHomeManagerModule = import ./modules/home-manager {
        inherit darkmatter-agents;
      };
      agentsHomeManagerModule = import ./modules/home-manager/agents.nix {
        inherit darkmatter-agents;
      };
      darwinSecretsModule = import ./modules/darwin/secrets.nix { inherit agenix; };
      nixosSecretsModule = import ./modules/nixos/secrets.nix { inherit agenix; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      imports = [
        inputs.flake-parts.flakeModules.modules
        ./modules/flake-parts
      ];
      flake = {
        # Flake-parts modules - for use in any flake-parts based flake
        # Usage: imports = [ inputs.darkmatter.flakeModules.default ];
        flakeModules = {
          default = ./modules/flake-parts;
          agenix-rekey = ./modules/flake-parts/ci/agenix-rekey.nix;
          r2 = ./modules/flake-parts/r2.nix;
        };
        homeManagerModules = {
          default = defaultHomeManagerModule;
          agents = agentsHomeManagerModule;
        };
        nixosModules = {
          default = nixosSecretsModule;
          secrets = nixosSecretsModule;
        };
        darwinModules = {
          default = darwinSecretsModule;
          secrets = darwinSecretsModule;
        };
      };

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        let
          rcloneGoogleDrive = pkgs.writeShellApplication {
            name = "rclone-google-drive";
            runtimeInputs = [
              pkgs.rclone
              pkgs.coreutils
              pkgs.sops
            ];
            text = ''
              set -euo pipefail

              export DARKMATTER_RCLONE_SOPS_FILE="${./ops/secrets/rclone-config.sops.yaml}"
              exec ${pkgs.bash}/bin/bash ${./ops/scripts/rclone-google-drive.sh} "$@"
            '';
          };

          rcloneDriveSetup = pkgs.writeShellApplication {
            name = "rclone-drive-setup";
            runtimeInputs = [
              pkgs.rclone
              pkgs.coreutils
              pkgs.sops
              pkgs.gum
              pkgs.gnugrep
            ];
            text = ''
              set -euo pipefail

              export DARKMATTER_RCLONE_SOPS_FILE="${./ops/secrets/rclone-config.sops.yaml}"
              exec ${pkgs.bash}/bin/bash ${./ops/scripts/rclone-drive-setup.sh} "$@"
            '';
          };
        in
        {
          packages = {
            rclone-google-drive = rcloneGoogleDrive;
            rclone-drive = rcloneGoogleDrive;
            rclone-drive-setup = rcloneDriveSetup;
          };
          apps = {
            rclone-google-drive = {
              type = "app";
              program = "${rcloneGoogleDrive}/bin/rclone-google-drive";
            };
            rclone-drive = {
              type = "app";
              program = "${rcloneGoogleDrive}/bin/rclone-google-drive";
            };
            rclone-drive-setup = {
              type = "app";
              program = "${rcloneDriveSetup}/bin/rclone-drive-setup";
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [ pkgs.gum ];
            shellHook = ''
              source ${./ops/scripts/devshell-hook.sh}
            '';
          };
          # Enable agenix-rekey workflow generation for this repo
          darkmatter.ci.agenix-rekey = {
            enable = true;
            cachix.enable = true;
            cachix.name = "darkmatter";
          };
          # Expose mount-darkmatter / unmount-darkmatter / configure-darkmatter-r2
          # apps that mount Cloudflare R2 buckets at ~/darkmatter/{public,team,personal}.
          darkmatter.r2.enable = true;
        };
    };
}

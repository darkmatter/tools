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

              export SOPS_KEYSERVICE="''${SOPS_KEYSERVICE:-tcp://sops-keyservice.tail6277a6.ts.net:5000}"
              encrypted_config="${./ops/secrets/rclone-config.sops.yaml}"
              generated_config=0

              usage() {
                echo "Usage: rclone-google-drive <mount-dir> [remote-or-remote-path]" >&2
                echo "Example: nix run github:darkmatter/nix#rclone-drive -- ~/Drive darkmatter-google-drive" >&2
                echo "Default RCLONE_CONFIG: decrypted from the checked-in SOPS config at runtime" >&2
              }

              if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
                usage
                exit 64
              fi

              mount_dir="$1"
              remote="''${2:-darkmatter-google-drive}"

              case "$mount_dir" in
                \~)
                  mount_dir="$HOME"
                  ;;
                \~/*)
                  mount_dir="$HOME/''${mount_dir#\~/}"
                  ;;
              esac

              cleanup() {
                if [ "$generated_config" -eq 1 ] && [ -n "''${RCLONE_CONFIG:-}" ]; then
                  rm -f "$RCLONE_CONFIG"
                fi
              }
              trap cleanup EXIT

              if [ -z "''${RCLONE_CONFIG:-}" ]; then
                runtime_base="''${XDG_RUNTIME_DIR:-}"
                if [ -z "$runtime_base" ]; then
                  runtime_base="''${TMPDIR:-/tmp}"
                fi

                runtime_dir="$runtime_base/darkmatter-rclone"
                mkdir -p "$runtime_dir"
                chmod 700 "$runtime_dir"

                export RCLONE_CONFIG="$runtime_dir/rclone.conf"
                generated_config=1

                echo "Decrypting rclone config from $encrypted_config"
                umask 077
                sops --decrypt --extract '["contents"]' "$encrypted_config" > "$RCLONE_CONFIG"
              elif [ ! -r "$RCLONE_CONFIG" ]; then
                echo "rclone config not found or not readable at: $RCLONE_CONFIG" >&2
                echo "Unset RCLONE_CONFIG to decrypt the checked-in SOPS config automatically, or set RCLONE_CONFIG to another readable rclone config file." >&2
                exit 66
              else
                export RCLONE_CONFIG
              fi

              source="$remote"
              case "$source" in
                *:*)
                  ;;
                *)
                  source="$source:"
                  ;;
              esac

              mkdir -p "$mount_dir"
              volname="$(basename "$mount_dir")"

              echo "Mounting $source at $mount_dir with RCLONE_CONFIG=$RCLONE_CONFIG"
              rclone mount "$source" "$mount_dir" --vfs-cache-mode=writes --volname "$volname"
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
            SOPS_KEYSERVICE = "tcp://sops-keyservice.tail6277a6.ts.net:5000";
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

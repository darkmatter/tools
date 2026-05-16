# Cloudflare R2 mount module (flake-parts)
#
# Exposes apps that let team members mount Cloudflare R2 buckets locally via
# rclone at a configurable base directory (default `~/darkmatter`). The
# module generates one rclone mount per entry in `darkmatter.r2.mounts`,
# plus an interactive helper to bootstrap the rclone remote.
#
# Usage:
#   imports = [ inputs.darkmatter.flakeModules.r2 ];
#   perSystem = { ... }: {
#     darkmatter.r2 = {
#       enable = true;
#       # accountId can also be supplied at runtime via R2_ACCOUNT_ID
#       accountId = "<cloudflare-account-id>";
#     };
#   };
#
#   nix run .#configure-darkmatter-r2   # one-time rclone remote setup
#   nix run .#mount-darkmatter          # mount all configured buckets
#   nix run .#mount-darkmatter -- lfs   # mount a single bucket by name
#   nix run .#unmount-darkmatter        # unmount everything
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  inherit (flake-parts-lib) mkPerSystemOption;
in
{
  options.perSystem = mkPerSystemOption (
    {
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.darkmatter.r2;

      mountModule = types.submodule (
        { name, ... }:
        {
          options = {
            bucket = mkOption {
              type = types.str;
              description = "R2 bucket name to mount.";
            };
            subdir = mkOption {
              type = types.str;
              default = name;
              description = "Subdirectory under `baseDir` where the bucket is mounted.";
            };
            vfsCacheMode = mkOption {
              type = types.nullOr (types.enum [
                "off"
                "minimal"
                "writes"
                "full"
              ]);
              default = null;
              description = ''
                Per-mount `--vfs-cache-mode`. When unset, the global
                `darkmatter.r2.vfsCacheMode` value is used.
              '';
            };
            extraMountArgs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional arguments forwarded to `rclone mount`.";
            };
          };
        }
      );

      mountNames = lib.attrNames cfg.mounts;

      # Shell-quote a list of strings into a single space-separated argv.
      shellArgs = args: lib.concatStringsSep " " (map lib.escapeShellArg args);

      mountEntry = name: m: ''
        ${lib.escapeShellArg name})
          bucket=${lib.escapeShellArg m.bucket}
          subdir=${lib.escapeShellArg m.subdir}
          target="$base/$subdir"
          vfs_cache_mode=${lib.escapeShellArg (if m.vfsCacheMode == null then cfg.vfsCacheMode else m.vfsCacheMode)}
          extra_args=(${shellArgs m.extraMountArgs})
          ;;
      '';

      mountCases = lib.concatStringsSep "\n" (
        lib.mapAttrsToList mountEntry cfg.mounts
      );

      unmountEntry = name: m: ''
        ${lib.escapeShellArg name})
          target=$base/${lib.escapeShellArg m.subdir}
          ;;
      '';

      unmountCases = lib.concatStringsSep "\n" (
        lib.mapAttrsToList unmountEntry cfg.mounts
      );

      knownNames = shellArgs mountNames;

      mountScript = pkgs.writeShellApplication {
        name = "mount-darkmatter"; meta.description = "Mount Cloudflare R2 buckets locally via rclone";
        runtimeInputs = [
          pkgs.rclone
          pkgs.coreutils
        ];
        text = ''
          set -euo pipefail

          remote=${lib.escapeShellArg cfg.remoteName}
          base="''${DARKMATTER_BASE_DIR:-${cfg.baseDir}}"
          base="''${base/#\~/$HOME}"

          if ! rclone listremotes | grep -qx "''${remote}:"; then
            echo "rclone remote '$remote' not found." >&2
            echo "Run: nix run ${lib.escapeShellArg "."}#configure-darkmatter-r2" >&2
            exit 1
          fi

          targets=("$@")
          if [ "''${#targets[@]}" -eq 0 ]; then
            targets=(${knownNames})
          fi

          mkdir -p "$base"

          for name in "''${targets[@]}"; do
            bucket=""
            target=""
            vfs_cache_mode=${lib.escapeShellArg cfg.vfsCacheMode}
            extra_args=()
            case "$name" in
              ${mountCases}
              *)
                echo "Unknown mount '$name'. Known: ${knownNames}" >&2
                exit 2
                ;;
            esac

            mkdir -p "$target"

            if mount | grep -F " on $target " >/dev/null 2>&1; then
              echo "[$name] already mounted at $target"
              continue
            fi

            echo "[$name] mounting $remote:$bucket -> $target"
            rclone mount "$remote:$bucket" "$target" \
              --daemon \
              --vfs-cache-mode="$vfs_cache_mode" \
              ${shellArgs cfg.extraMountArgs} \
              "''${extra_args[@]}"
          done
        '';
      };

      unmountScript = pkgs.writeShellApplication {
        name = "unmount-darkmatter"; meta.description = "Unmount Cloudflare R2 buckets";
        runtimeInputs = [
          pkgs.coreutils
        ];
        text = ''
          set -euo pipefail

          base="''${DARKMATTER_BASE_DIR:-${cfg.baseDir}}"
          base="''${base/#\~/$HOME}"

          targets=("$@")
          if [ "''${#targets[@]}" -eq 0 ]; then
            targets=(${knownNames})
          fi

          unmount() {
            local path="$1"
            if ! mount | grep -F " on $path " >/dev/null 2>&1; then
              echo "[$(basename "$path")] not mounted"
              return 0
            fi
            if command -v fusermount3 >/dev/null 2>&1; then
              fusermount3 -u "$path"
            elif command -v fusermount >/dev/null 2>&1; then
              fusermount -u "$path"
            else
              umount "$path"
            fi
            echo "[$(basename "$path")] unmounted"
          }

          for name in "''${targets[@]}"; do
            target=""
            case "$name" in
              ${unmountCases}
              *)
                echo "Unknown mount '$name'. Known: ${knownNames}" >&2
                exit 2
                ;;
            esac
            unmount "$target"
          done
        '';
      };

      configureScript = pkgs.writeShellApplication {
        name = "configure-darkmatter-r2"; meta.description = "Configure rclone remote for Cloudflare R2";
        runtimeInputs = [
          pkgs.rclone
          pkgs.coreutils
        ];
        text = ''
          set -euo pipefail

          remote=${lib.escapeShellArg cfg.remoteName}
          account_id="''${R2_ACCOUNT_ID:-${cfg.accountId}}"
          access_key="''${R2_ACCESS_KEY_ID:-}"
          secret_key="''${R2_SECRET_ACCESS_KEY:-}"

          if [ -z "$account_id" ]; then
            read -r -p "Cloudflare account id: " account_id
          fi
          if [ -z "$access_key" ]; then
            read -r -p "R2 access key id: " access_key
          fi
          if [ -z "$secret_key" ]; then
            read -r -s -p "R2 secret access key: " secret_key
            echo
          fi

          endpoint="https://''${account_id}.r2.cloudflarestorage.com"

          rclone config create "$remote" s3 \
            provider Cloudflare \
            access_key_id "$access_key" \
            secret_access_key "$secret_key" \
            endpoint "$endpoint" \
            region auto \
            acl private \
            --non-interactive \
            >/dev/null

          echo "Configured rclone remote '$remote' against $endpoint"
          echo "Mounts available: ${knownNames}"
        '';
      };
    in
    {
      options.darkmatter.r2 = {
        enable = mkEnableOption "Cloudflare R2 mount apps backed by rclone";

        accountId = mkOption {
          type = types.str;
          default = "";
          description = ''
            Cloudflare account id used to derive the R2 endpoint
            (`https://<accountId>.r2.cloudflarestorage.com`). Can be
            overridden at runtime via the `R2_ACCOUNT_ID` env var.
          '';
        };

        remoteName = mkOption {
          type = types.str;
          default = "darkmatter-r2";
          description = "Name of the rclone remote to create and mount from.";
        };

        baseDir = mkOption {
          type = types.str;
          default = "~/darkmatter";
          description = ''
            Base directory under which each mount's subdirectory is created.
            Tilde is expanded against `$HOME` at runtime. Override per-invocation
            via the `DARKMATTER_BASE_DIR` env var.
          '';
        };

        vfsCacheMode = mkOption {
          type = types.enum [
            "off"
            "minimal"
            "writes"
            "full"
          ];
          default = "writes";
          description = "Value passed to `rclone mount --vfs-cache-mode`.";
        };

        extraMountArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Extra arguments appended to every `rclone mount` invocation.";
        };

        mounts = mkOption {
          type = types.attrsOf mountModule;
          default = {
            public = {
              bucket = "darkmatter-public";
            };
            runtime = {
              bucket = "darkmatter-runtime";
            };
            lfs = {
              bucket = "darkmatter-lfs";
              vfsCacheMode = "full";
              extraMountArgs = [
                "--vfs-cache-max-size"
                "200G"
                "--vfs-cache-max-age"
                "720h"
                "--dir-cache-time"
                "1h"
                "--poll-interval"
                "0"
              ];
            };
            team = {
              bucket = "darkmatter-team";
            };
            personal = {
              bucket = "darkmatter-personal";
            };
          };
          description = ''
            Set of buckets to mount under `baseDir`. The attribute name is
            used as the subdirectory name (overridable via `subdir`) and as
            the argument accepted by `mount-darkmatter`/`unmount-darkmatter`.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        packages = {
          mount-darkmatter = mountScript;
          unmount-darkmatter = unmountScript;
          configure-darkmatter-r2 = configureScript;
        };
        apps = {
          mount-darkmatter = {
            type = "app";
            program = "${mountScript}/bin/mount-darkmatter"; meta.description = "Mount Cloudflare R2 buckets locally via rclone";
          };
          unmount-darkmatter = {
            type = "app";
            program = "${unmountScript}/bin/unmount-darkmatter"; meta.description = "Unmount Cloudflare R2 buckets";
          };
          configure-darkmatter-r2 = {
            type = "app";
            program = "${configureScript}/bin/configure-darkmatter-r2"; meta.description = "Configure rclone remote for Cloudflare R2";
          };
        };
      };
    }
  );
}

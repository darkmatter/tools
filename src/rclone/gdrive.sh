#!/usr/bin/env bash
# Mount a Google Drive rclone remote, defaulting to the shared Darkmatter
# SOPS-managed rclone config and merging any personal remotes from the user's
# local rclone config.

set -euo pipefail

SOPS_KEYSERVICE="${SOPS_KEYSERVICE:-tcp://sops-keyservice.tail6277a6.ts.net:5000}"
export SOPS_KEYSERVICE

SHARED_REMOTE="${RCLONE_SHARED_REMOTE:-darkmatter-google-drive}"
LOCAL_RCLONE_CONFIG="${RCLONE_LOCAL_CONFIG:-$HOME/.config/rclone/rclone.conf}"

# The flake wrapper sets this to a Nix-store path for the encrypted config.
# Keep a repo-relative fallback so the script is also usable from a checkout.
if [[ -z "${DARKMATTER_RCLONE_SOPS_FILE:-}" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
  DARKMATTER_RCLONE_SOPS_FILE="$REPO_ROOT/ops/secrets/rclone-config.sops.yaml"
fi

encrypted_config="$DARKMATTER_RCLONE_SOPS_FILE"
generated_config=0

usage() {
  echo "Usage:" >&2
  echo "  rclone-google-drive <mount-dir> [remote-or-remote-path]" >&2
  echo "  rclone-google-drive reconnect [remote]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  nix run github:darkmatter/tools#rclone-drive -- ~/Drive darkmatter-google-drive" >&2
  echo "  nix run github:darkmatter/tools#rclone-drive -- ~/darkmatter/\$USER darkmatter-personal" >&2
  echo "  nix run github:darkmatter/tools#rclone-drive -- reconnect darkmatter-google-drive" >&2
  echo "" >&2
  echo "Default RCLONE_CONFIG: decrypted from the checked-in SOPS config at runtime" >&2
  echo "Personal remotes and per-user OAuth tokens from $LOCAL_RCLONE_CONFIG are merged in automatically" >&2
}

cleanup() {
  if [[ "$generated_config" -eq 1 && -n "${RCLONE_CONFIG:-}" ]]; then
    rm -f "$RCLONE_CONFIG"
  fi
}
trap cleanup EXIT

remote_name() {
  local remote="$1"
  remote="${remote%%:*}"
  printf '%s\n' "$remote"
}

extract_config_value() {
  local config_file="$1"
  local remote="$2"
  local key="$3"
  local line
  local value=""

  while IFS= read -r line; do
    case "$line" in
      "$key"\ =*)
        value="${line#"$key = "}"
        ;;
    esac
  done < <(rclone --config "$config_file" config show "$remote")

  printf '%s\n' "$value"
}

extract_token() {
  extract_config_value "$1" "$2" token
}

reconnect_remote() {
  local config_file="$1"
  local remote="$2"
  local team_drive

  team_drive="$(extract_config_value "$config_file" "$remote" team_drive)"

  if [[ -n "$team_drive" ]]; then
    rclone --config "$config_file" --auto-confirm --drive-team-drive "$team_drive" config reconnect "$remote:"
  else
    rclone --config "$config_file" --auto-confirm config reconnect "$remote:"
  fi
}

write_local_token() {
  local local_config="$1"
  local remote="$2"
  local token="$3"
  local local_dir
  local tmp
  local line
  local in_section=0
  local section_found=0
  local token_written=0

  local_dir="$(dirname -- "$local_config")"
  mkdir -p "$local_dir"
  chmod 700 "$local_dir"

  tmp="$local_config.tmp.$$"
  umask 077

  if [[ -r "$local_config" ]]; then
    : > "$tmp"

    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        \[*\])
          if [[ "$in_section" -eq 1 && "$token_written" -eq 0 ]]; then
            printf 'token = %s\n' "$token" >> "$tmp"
            token_written=1
          fi

          if [[ "$line" == "[$remote]" ]]; then
            in_section=1
            section_found=1
            token_written=0
          else
            in_section=0
          fi

          printf '%s\n' "$line" >> "$tmp"
          ;;
        token\ =*)
          if [[ "$in_section" -eq 1 ]]; then
            printf 'token = %s\n' "$token" >> "$tmp"
            token_written=1
          else
            printf '%s\n' "$line" >> "$tmp"
          fi
          ;;
        *)
          printf '%s\n' "$line" >> "$tmp"
          ;;
      esac
    done < "$local_config"

    if [[ "$in_section" -eq 1 && "$token_written" -eq 0 ]]; then
      printf 'token = %s\n' "$token" >> "$tmp"
    fi

    if [[ "$section_found" -eq 0 ]]; then
      printf '\n[%s]\n' "$remote" >> "$tmp"
      printf 'type = drive\n' >> "$tmp"
      printf 'token = %s\n' "$token" >> "$tmp"
    fi
  else
    {
      printf '[%s]\n' "$remote"
      printf 'type = drive\n'
      printf 'token = %s\n' "$token"
    } > "$tmp"
  fi

  chmod 600 "$tmp"
  mv "$tmp" "$local_config"
}

prepare_config() {
  if [[ -z "${RCLONE_CONFIG:-}" ]]; then
    runtime_base="${XDG_RUNTIME_DIR:-}"
    if [[ -z "$runtime_base" ]]; then
      runtime_base="${TMPDIR:-/tmp}"
    fi

    runtime_dir="$runtime_base/darkmatter-rclone"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"

    export RCLONE_CONFIG="$runtime_dir/rclone.conf"
    generated_config=1

    echo "Decrypting rclone config from $encrypted_config"
    umask 077
    sops --decrypt --extract '["contents"]' "$encrypted_config" > "$RCLONE_CONFIG"

    # Merge in personal remotes and per-user OAuth tokens from the user's local rclone config.
    if [[ -r "$LOCAL_RCLONE_CONFIG" ]]; then
      echo "Merging personal remotes and OAuth tokens from $LOCAL_RCLONE_CONFIG"
      echo "" >> "$RCLONE_CONFIG"
      cat "$LOCAL_RCLONE_CONFIG" >> "$RCLONE_CONFIG"
    fi
  elif [[ ! -r "$RCLONE_CONFIG" ]]; then
    echo "rclone config not found or not readable at: $RCLONE_CONFIG" >&2
    echo "Unset RCLONE_CONFIG to decrypt the checked-in SOPS config automatically, or set RCLONE_CONFIG to another readable rclone config file." >&2
    exit 66
  else
    export RCLONE_CONFIG
  fi
}

mode="mount"

if [[ "${1:-}" == "reconnect" || "${1:-}" == "auth" ]]; then
  mode="reconnect"
  shift

  if [[ "$#" -gt 1 ]]; then
    usage
    exit 64
  fi

  remote="${1:-$SHARED_REMOTE}"
elif [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
  usage
  exit 64
else
  mount_dir="$1"
  remote="${2:-$SHARED_REMOTE}"

  case "$mount_dir" in
    ~)
      mount_dir="$HOME"
      ;;
    ~/*)
      mount_dir="$HOME/${mount_dir#~/}"
      ;;
  esac
fi

prepare_config

remote_name="$(remote_name "$remote")"

if [[ "$mode" == "reconnect" ]]; then
  if [[ -z "$remote_name" ]]; then
    echo "Remote name is required." >&2
    exit 64
  fi

  echo "Launching browser OAuth flow for $remote_name"
  reconnect_remote "$RCLONE_CONFIG" "$remote_name"

  token="$(extract_token "$RCLONE_CONFIG" "$remote_name")"
  if [[ -z "$token" ]]; then
    echo "OAuth reconnect completed, but no token was found for '$remote_name'." >&2
    exit 1
  fi

  write_local_token "$LOCAL_RCLONE_CONFIG" "$remote_name" "$token"
  echo "Saved per-user OAuth token for '$remote_name' to $LOCAL_RCLONE_CONFIG"
  echo "Future mounts will merge this local token with the shared SOPS-managed config."
  exit 0
fi

source="$remote"
case "$source" in
  *:*)
    ;;
  *)
    source="$source:"
    ;;
esac

if [[ "$remote_name" == "$SHARED_REMOTE" ]]; then
  token="$(extract_token "$RCLONE_CONFIG" "$remote_name")"
  if [[ -z "$token" ]]; then
    echo "The shared Google Drive remote '$remote_name' does not have a local OAuth token yet." >&2
    echo "Run this once to open the browser OAuth flow and save your per-user token:" >&2
    echo "  nix run github:darkmatter/tools#rclone-drive -- reconnect $remote_name" >&2
    exit 67
  fi
fi

mkdir -p "$mount_dir"
volname="$(basename "$mount_dir")"

echo "Mounting $source at $mount_dir with RCLONE_CONFIG=$RCLONE_CONFIG"
rclone mount "$source" "$mount_dir" --vfs-cache-mode=writes --volname "$volname"

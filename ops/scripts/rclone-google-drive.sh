#!/usr/bin/env bash
# Mount a Google Drive rclone remote, defaulting to the shared Darkmatter
# SOPS-managed rclone config and merging any personal remotes from the user's
# local rclone config.

set -euo pipefail

SOPS_KEYSERVICE="${SOPS_KEYSERVICE:-tcp://sops-keyservice.tail6277a6.ts.net:5000}"
export SOPS_KEYSERVICE

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
  echo "Usage: rclone-google-drive <mount-dir> [remote-or-remote-path]" >&2
  echo "Example: nix run github:darkmatter/nix#rclone-drive -- ~/Drive darkmatter-google-drive" >&2
  echo "         nix run github:darkmatter/nix#rclone-drive -- ~/darkmatter/$USER darkmatter-personal" >&2
  echo "Default RCLONE_CONFIG: decrypted from the checked-in SOPS config at runtime" >&2
  echo "Personal remotes from ~/.config/rclone/rclone.conf are merged in automatically" >&2
}

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
  usage
  exit 64
fi

mount_dir="$1"
remote="${2:-darkmatter-google-drive}"

case "$mount_dir" in
  ~)
    mount_dir="$HOME"
    ;;
  ~/*)
    mount_dir="$HOME/${mount_dir#~/}"
    ;;
esac

cleanup() {
  if [[ "$generated_config" -eq 1 && -n "${RCLONE_CONFIG:-}" ]]; then
    rm -f "$RCLONE_CONFIG"
  fi
}
trap cleanup EXIT

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

  # Merge in personal remotes from the user's local rclone config.
  local_config="$HOME/.config/rclone/rclone.conf"
  if [[ -r "$local_config" ]]; then
    echo "Merging personal remotes from $local_config"
    echo "" >> "$RCLONE_CONFIG"
    cat "$local_config" >> "$RCLONE_CONFIG"
  fi
elif [[ ! -r "$RCLONE_CONFIG" ]]; then
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

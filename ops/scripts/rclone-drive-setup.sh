#!/usr/bin/env bash
# nix/ops/scripts/rclone-drive-setup.sh
#
# Interactive setup wizard for Darkmatter Google Drive mounts.
#
# Run via:
#   nix run github:darkmatter/nix#rclone-drive-setup
#
# Requires: gum, rclone, sops, grep, mount, chmod, mkdir, basename, id
# These should be provided by the flake wrapper.

set -euo pipefail

SOPS_KEYSERVICE="${SOPS_KEYSERVICE:-tcp://sops-keyservice.tail6277a6.ts.net:5000}"
export SOPS_KEYSERVICE

SHARED_REMOTE="${RCLONE_SHARED_REMOTE:-darkmatter-google-drive}"
PERSONAL_REMOTE="${RCLONE_PERSONAL_REMOTE:-darkmatter-personal}"
PERSONAL_CONFIG="${RCLONE_PERSONAL_CONFIG:-$HOME/.config/rclone/rclone.conf}"

# The flake wrapper should set this to a Nix-store path for the encrypted config.
# Keep a repo-relative fallback so the script is also usable from a checkout.
if [[ -z "${DARKMATTER_RCLONE_SOPS_FILE:-}" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
  DARKMATTER_RCLONE_SOPS_FILE="$REPO_ROOT/ops/secrets/rclone-config.sops.yaml"
fi

# ── Colours / style helpers ───────────────────────────────────────────────────
banner() {
  echo >&2
  gum style >&2 \
    --foreground 14 --border-foreground 212 --border="none" \
    --margin "1 1" \
    "$1"
}

header() {
  echo >&2
  gum style >&2 \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 64 --margin "1 0" --padding "0 2" \
    "$1"
}

step() {
  gum style >&2 --foreground 99 "▶ $1"
}

ok() {
  gum style >&2 --foreground 82 "✓ $1"
}

info() {
  gum style >&2 --foreground 99 "ℹ $1"
}

subtle() {
  gum style >&2 --faint "$1"
}

warn() {
  gum style >&2 --foreground 214 "⚠ $1"
}

die() {
  gum style >&2 --foreground 196 "✗ $1"
  exit 1
}

# ── Generic helpers ───────────────────────────────────────────────────────────
check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1"
  elif command -v nix >/dev/null 2>&1 && nix search "nixpkgs#$1" . >/dev/null 2>&1; then
    info "Installing $1 via nix..."
    nix profile add "nixpkgs#$1"
    ok "$1"
  else
    die "$1 not found — run this via: nix run github:darkmatter/nix#rclone-drive-setup"
  fi
}

expand_path() {
  case "$1" in
    \~)
      printf '%s\n' "$HOME"
      ;;
    \~/*)
      printf '%s/%s\n' "$HOME" "${1#\~/}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

runtime_dir() {
  local runtime_base="${XDG_RUNTIME_DIR:-}"

  if [[ -z "$runtime_base" ]]; then
    runtime_base="${TMPDIR:-/tmp}"
  fi

  printf '%s\n' "$runtime_base/darkmatter-rclone"
}

decrypt_shared_config() {
  local dir
  local shared_config

  [[ -r "$DARKMATTER_RCLONE_SOPS_FILE" ]] ||
    die "Encrypted rclone config not found or not readable: $DARKMATTER_RCLONE_SOPS_FILE"

  dir="$(runtime_dir)"
  mkdir -p "$dir"
  chmod 700 "$dir"

  shared_config="$dir/shared-rclone.conf"

  step "Decrypting shared Google Drive config"
  gum spin >&2 --spinner dot --title "Using $SOPS_KEYSERVICE" -- \
    sops --decrypt --extract '["contents"]' --output "$shared_config" "$DARKMATTER_RCLONE_SOPS_FILE"

  chmod 600 "$shared_config"

  if ! rclone --config "$shared_config" listremotes | grep -Fxq "$SHARED_REMOTE:"; then
    die "Shared rclone config does not define remote '$SHARED_REMOTE'"
  fi

  ok "Shared config decrypted"
  printf '%s\n' "$shared_config"
}

# ── FUSE helpers ──────────────────────────────────────────────────────────────
has_fuse() {
  case "$(uname -s)" in
    Darwin)
      [[ -d /Library/Filesystems/macfuse.fs ]] ||
        pkgutil --pkg-info io.macfuse.pkg.Core >/dev/null 2>&1
      ;;
    Linux)
      { command -v fusermount3 >/dev/null 2>&1 || command -v fusermount >/dev/null 2>&1; } &&
        [[ -e /dev/fuse ]]
      ;;
    *)
      return 1
      ;;
  esac
}

install_fuse() {
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        gum spin >&2 --spinner dot --title "Installing macFUSE with Homebrew..." -- \
          brew install --cask macfuse
        warn "If macOS prompts for approval, approve macFUSE in System Settings and reboot before mounting."
      else
        warn "Homebrew was not found."
        warn "Install macFUSE from https://macfuse.github.io/ and rerun this wizard."
        return 1
      fi
      ;;
    Linux)
      command -v sudo >/dev/null 2>&1 ||
        die "sudo is required for automatic FUSE installation on Linux."

      if command -v apt-get >/dev/null 2>&1; then
        gum spin >&2 --spinner dot --title "Updating apt package metadata..." -- \
          sudo apt-get update
        gum spin >&2 --spinner dot --title "Installing fuse3..." -- \
          sudo apt-get install -y fuse3
      elif command -v dnf >/dev/null 2>&1; then
        gum spin >&2 --spinner dot --title "Installing fuse3 with dnf..." -- \
          sudo dnf install -y fuse3
      elif command -v pacman >/dev/null 2>&1; then
        gum spin >&2 --spinner dot --title "Installing fuse3 with pacman..." -- \
          sudo pacman -S --needed fuse3
      else
        warn "Could not find apt-get, dnf, or pacman."
        warn "Install FUSE for your distro and rerun this wizard."
        return 1
      fi
      ;;
    *)
      warn "Unsupported OS for automatic FUSE installation. Please install FUSE manually."
      return 1
      ;;
  esac
}

ensure_fuse() {
  header "2 · FUSE support"

  if has_fuse; then
    ok "FUSE support detected"
    return 0
  fi

  warn "FUSE support was not detected."
  gum style >&2 --faint "rclone mount requires FUSE. On macOS this means macFUSE."

  if gum confirm "Install FUSE now where possible?"; then
    install_fuse || true
  fi

  if has_fuse; then
    ok "FUSE support detected"
    return 0
  fi

  warn "FUSE still was not detected. Mounting may fail until FUSE is installed and approved."
  gum confirm "Continue setup anyway?" || exit 0
}

# ── rclone helpers ────────────────────────────────────────────────────────────
ensure_personal_remote() {
  local personal_config

  personal_config="$(expand_path "$PERSONAL_CONFIG")"
  mkdir -p "$(dirname "$personal_config")"

  if rclone --config "$personal_config" listremotes | grep -Fxq "$PERSONAL_REMOTE:"; then
    ok "Personal remote '$PERSONAL_REMOTE' already exists"
    printf '%s\n' "$personal_config"
    return 0
  fi

  step "Configure your personal Google Drive"
  gum style >&2 --faint "The wizard will launch rclone's Google Drive OAuth flow."
  gum style >&2 --faint "Remote name: $PERSONAL_REMOTE"

  if gum confirm "Launch rclone config for your personal Drive now?"; then
    rclone --config "$personal_config" config create "$PERSONAL_REMOTE" drive scope drive
  else
    warn "Skipping personal Drive configuration"
    return 1
  fi

  if ! rclone --config "$personal_config" listremotes | grep -Fxq "$PERSONAL_REMOTE:"; then
    warn "Personal remote '$PERSONAL_REMOTE' was not configured."
    return 1
  fi

  ok "Personal remote configured"
  printf '%s\n' "$personal_config"
}

is_mounted() {
  mount | grep -F " on $1 " >/dev/null 2>&1
}

mount_drive() {
  local label="$1"
  local config_file="$2"
  local remote_name="$3"
  local target="$4"
  local volname

  volname="$(basename "$target")"
  [[ -n "$volname" ]] || volname="$remote_name"

  mkdir -p "$target"

  if is_mounted "$target"; then
    ok "$label is already mounted at $target"
    return 0
  fi

  if ! has_fuse; then
    warn "Attempting mount even though FUSE was not detected."
  fi

  gum spin >&2 --spinner dot --title "Mounting $label at $target..." -- \
    rclone --config "$config_file" mount "$remote_name:" "$target" --daemon --vfs-cache-mode=writes --volname "$volname"

  ok "$label mounted at $target"
}

# ── Welcome ───────────────────────────────────────────────────────────────────
ASCII_LOGO=$(cat <<'EOF'
       __              __                      __   __
  ____/ /____ _ _____ / /__ ____ ___   ____ _ / /_ / /_ ___   _____
 / __  // __ `// ___// //_// __ `__ \ / __ `// __// __// _ \ / ___/
/ /_/ // /_/ // /   / ,<  / / / / / // /_/ // /_ / /_ /  __// /
\__,_/ \__,_//_/   /_/|_|/_/ /_/ /_/ \__,_/ \__/ \__/ \___//_/
EOF
)
banner "$ASCII_LOGO"
# header "Darkmatter Google Drive setup"
gum style >&2 --align center --width 64 \
  "This wizard will configure shared and optional personal" \
  "Google Drive mounts using rclone, SOPS, and gum."

echo >&2
gum confirm "Ready to begin?" || exit 0

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
header "1 · Prerequisites"
check_cmd rclone
check_cmd sops
check_cmd gum
check_cmd grep
check_cmd mount
check_cmd chmod
check_cmd mkdir
check_cmd basename
check_cmd id

# ── 2. FUSE ───────────────────────────────────────────────────────────────────
ensure_fuse

# ── 3. Mount paths ────────────────────────────────────────────────────────────
header "3 · Mount paths"

username="${USER:-$(id -un)}"
shared_default="$HOME/darkmatter/shared"
personal_default="$HOME/darkmatter/$username"

subtle "Team runtime drive: this mount is used to share files with the team."
shared_path="$(gum input --prompt "choose path › " --value "$shared_default" --width 70)"
[[ -n "$shared_path" ]] || die "Shared Drive mount path is required."
shared_path="$(expand_path "$shared_path")"
ok "Shared Drive will mount at $shared_path"

configure_personal=0
personal_path=""

if gum confirm "Configure and mount a personal Google Drive too?"; then
  configure_personal=1
  personal_path="$(gum input --prompt "Personal Drive mount path › " --value "$personal_default" --width 70)"
  [[ -n "$personal_path" ]] || die "Personal Drive mount path is required."
  personal_path="$(expand_path "$personal_path")"
  ok "Personal Drive will mount at $personal_path"
fi

# ── 4. Shared Drive ───────────────────────────────────────────────────────────
header "4 · Shared Drive"

shared_config="$(decrypt_shared_config)"

gum spin >&2 --spinner dot --title "Checking shared Google Drive remote..." -- \
  rclone --config "$shared_config" about "$SHARED_REMOTE:" >/dev/null

ok "Shared Google Drive remote is reachable"
mount_drive "Shared Google Drive" "$shared_config" "$SHARED_REMOTE" "$shared_path"

# ── 5. Personal Drive ─────────────────────────────────────────────────────────
if [[ "$configure_personal" -eq 1 ]]; then
  header "5 · Personal Drive"

  if personal_config="$(ensure_personal_remote)"; then
    mount_drive "Personal Google Drive" "$personal_config" "$PERSONAL_REMOTE" "$personal_path"
  else
    warn "Personal Drive was not mounted."
  fi
fi

# ── 6. Summary ────────────────────────────────────────────────────────────────
header "✓ Setup complete"

gum style >&2 --width 64 --padding "0 2" \
  "Shared mount:   $shared_path"

if [[ "$configure_personal" -eq 1 && -n "$personal_path" ]]; then
  gum style >&2 --width 64 --padding "0 2" \
    "Personal mount: $personal_path"
fi

gum style >&2 --faint \
  "Unmount later with: umount <mount-path> on macOS, or fusermount3 -u <mount-path> on Linux."

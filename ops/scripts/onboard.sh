#!/usr/bin/env bash
# First-run onboarding launcher for `nix run github:darkmatter/tools`.

set -euo pipefail

FLAKE_REF="${DARKMATTER_NIX_FLAKE_REF:-github:darkmatter/tools}"
RCLONE_DRIVE_SETUP_BIN="${DARKMATTER_RCLONE_DRIVE_SETUP_BIN:-rclone-drive-setup}"
RCLONE_DRIVE_LAUNCH_AGENT_BIN="${DARKMATTER_RCLONE_DRIVE_LAUNCH_AGENT_BIN:-rclone-drive-launch-agent}"
DEFAULT_CLONE_PATH="$HOME/git/darkmatter/tools"

expand_path() {
  case "$1" in
    ~)
      printf '%s\n' "$HOME"
      ;;
    ~/*)
      printf '%s/%s\n' "$HOME" "${1#\~/}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

render_header() {
  cat <<'EOF' | gum format -t template
{{ Foreground "212" (Bold "Darkmatter Nix Devkit") }}
{{ Foreground "103" (Faint "One command onboarding for the Darkmatter toolchain") }}

{{ Foreground "15" `This launcher can set up shared runtime state without requiring you to clone the repo first. If you want the full local developer experience, clone the repo and let direnv activate the devshell welcome message.` }}
EOF
}

show_command_row() {
  local label="$1"
  local prefix="$2"
  local command="$3"

  gum style --foreground 99 "$label"
  printf '%s%s\n\n' \
    "$(gum style --foreground 103 "  $prefix ")" \
    "$(gum style --foreground 156 "$command")"
}

show_commands() {
  gum style --foreground 212 --bold "Useful commands"
  echo
  show_command_row "Start this launcher" "nix run" "$FLAKE_REF"
  show_command_row "Run the Google Drive setup wizard directly" "nix run" "$FLAKE_REF#rclone-drive-setup"
  show_command_row "Install the shared Drive automount directly" "nix run" "$FLAKE_REF#rclone-drive-launch-agent -- install"
  show_command_row "Enter a temporary dev shell without cloning" "nix develop" "$FLAKE_REF"
}

clone_repo() {
  local target

  target="$(gum input --prompt "clone path › " --value "$DEFAULT_CLONE_PATH" --width 70)"
  [ -n "$target" ] || return 0
  target="$(expand_path "$target")"

  if [ -e "$target" ]; then
    gum style --foreground 214 "Path already exists: $target"
    return 1
  fi

  mkdir -p "$(dirname "$target")"
  git clone https://github.com/darkmatter/tools "$target"

  echo
  gum style --foreground 156 --bold "Cloned Darkmatter Nix Devkit"
  echo
  gum style --foreground 99 "Next steps"
  printf '%s%s\n' \
    "$(gum style --foreground 103 "  cd ")" \
    "$(gum style --foreground 156 "$target")"
  gum style --foreground 103 "  direnv allow"
}

main() {
  clear || true
  render_header
  echo

  choice="$(
    gum choose \
      "Install shared Google Drive" \
      "Install shared Drive automount" \
      "Clone this repo" \
      "Enter temporary dev shell" \
      "Show commands" \
      "Quit"
  )"

  case "$choice" in
    "Install shared Google Drive")
      exec "$RCLONE_DRIVE_SETUP_BIN"
      ;;
    "Install shared Drive automount")
      exec "$RCLONE_DRIVE_LAUNCH_AGENT_BIN" install
      ;;
    "Clone this repo")
      clone_repo
      ;;
    "Enter temporary dev shell")
      exec nix develop "$FLAKE_REF"
      ;;
    "Show commands")
      show_commands
      ;;
    "Quit"|"")
      exit 0
      ;;
  esac
}

main "$@"

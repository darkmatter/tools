#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CLONE_PATH="$HOME/git/darkmatter/tools"
KEY_COMMENT="# darkmatter/tools generated key"
USERNAME=""
KEY_NAME=""
REPO_PATH="${DARKMATTER_TOOLS_REPO:-}"
COMMIT_CHANGES=1
PUSH_CHANGES=1
DRY_RUN=0
FORCE=0

usage() {
  cat <<USAGE
Usage: sops-join [options]

Generate an age identity, add its public recipient to ops/keys/team/,
regenerate .sops.yaml, and optionally commit + push so CI can rekey secrets.

Options:
  --username USER       GitHub username to use for the key file
  --key-name NAME       ops/keys/team/<NAME>.pub file name (default: username)
  --repo PATH           Local darkmatter/tools checkout (default: current repo or ~/git/darkmatter/tools)
  --no-commit           Do not commit changes
  --no-push             Commit locally but do not push
  --force               Overwrite an existing ops/keys/team/<NAME>.pub
  --dry-run             Show intended changes without writing files
  -h, --help            Show this help message
USAGE
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --username)
        USERNAME="${2:-}"
        shift 2
        ;;
      --key-name)
        KEY_NAME="${2:-}"
        shift 2
        ;;
      --repo)
        REPO_PATH="${2:-}"
        shift 2
        ;;
      --no-commit)
        COMMIT_CHANGES=0
        PUSH_CHANGES=0
        shift
        ;;
      --no-push)
        PUSH_CHANGES=0
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        COMMIT_CHANGES=0
        PUSH_CHANGES=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

info() {
  gum log -l info "$@" >&2
}

success() {
  printf '%s %s\n' "$(gum style --foreground 156 SUCCESS)" "$*" >&2
}

error() {
  gum log -l error "$@" >&2
}

expand_path() {
  case "$1" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${1#\~/}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

standard_age_keys_path() {
  if [ -n "${SOPS_AGE_KEY_FILE:-}" ]; then
    printf '%s\n' "$SOPS_AGE_KEY_FILE"
    return 0
  fi

  case "$(uname -s)" in
    Darwin*)
      printf '%s\n' "$HOME/Library/Application Support/sops/age/keys.txt"
      ;;
    *)
      printf '%s\n' "$HOME/.config/sops/age/keys.txt"
      ;;
  esac
}

repo_has_tools_layout() {
  [ -f "$1/sops.nix" ] && [ -d "$1/ops/keys" ] && [ -f "$1/flake.nix" ]
}

current_git_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

ensure_repo() {
  local root target

  if [ -n "$REPO_PATH" ]; then
    target="$(expand_path "$REPO_PATH")"
    if repo_has_tools_layout "$target"; then
      printf '%s\n' "$target"
      return 0
    fi
    error "Not a darkmatter/tools checkout: $target"
    exit 1
  fi

  root="$(current_git_root)"
  if [ -n "$root" ] && repo_has_tools_layout "$root"; then
    printf '%s\n' "$root"
    return 0
  fi

  if repo_has_tools_layout "$DEFAULT_CLONE_PATH"; then
    printf '%s\n' "$DEFAULT_CLONE_PATH"
    return 0
  fi

  target="$(gum input --prompt "clone path › " --value "$DEFAULT_CLONE_PATH" --width 70)"
  [ -n "$target" ] || exit 1
  target="$(expand_path "$target")"

  if [ "$DRY_RUN" = "1" ]; then
    info "Dry run: would clone https://github.com/darkmatter/tools to $target"
    printf '%s\n' "$target"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  git clone https://github.com/darkmatter/tools "$target"
  printf '%s\n' "$target"
}

get_username() {
  local user="$USERNAME"

  if [ -z "$user" ] && command -v gh >/dev/null 2>&1; then
    user="$(gh api user --jq .login 2>/dev/null || true)"
  fi

  if [ -z "$user" ]; then
    user="$(git config github.user 2>/dev/null || true)"
  fi

  if [ -z "$user" ]; then
    user="$(gum input --placeholder "GitHub username" --width 50)"
  fi

  if [ -z "$user" ]; then
    error "Username cannot be empty."
    exit 1
  fi

  case "$user" in
    *[!A-Za-z0-9_-]*)
      error "Invalid username '$user'. Use only letters, numbers, underscores, and hyphens."
      exit 1
      ;;
  esac

  printf '%s\n' "$user"
}

ensure_team_recipient_available() {
  local repo="$1"
  local key_name="$2"
  local key_file="$repo/ops/keys/team/$key_name.pub"

  if [ -e "$key_file" ] && [ "$FORCE" != "1" ]; then
    if gum confirm "Recipient file exists: ops/keys/team/$key_name.pub. Overwrite it?"; then
      return 0
    fi

    error "Recipient file already exists. Re-run with --key-name or --force."
    exit 1
  fi
}

generate_age_identity() {
  local keys_path="$1"
  local tmpdir tmpfile pub_key

  tmpdir="$(mktemp -d)"
  chmod 700 "$tmpdir"
  tmpfile="$tmpdir/key.txt"

  age-keygen -o "$tmpfile" >/dev/null 2>&1
  pub_key="$(age-keygen -y "$tmpfile" 2>/dev/null)"

  case "$pub_key" in
    age1*)
      ;;
    *)
      error "Generated public key does not look like an age recipient: $pub_key"
      exit 1
      ;;
  esac

  if [ "$DRY_RUN" = "1" ]; then
    info "Dry run: would append the generated private key to $keys_path"
    printf '%s\n' "$pub_key"
    rm -rf "$tmpdir"
    return 0
  fi

  mkdir -p "$(dirname "$keys_path")"
  chmod 700 "$(dirname "$keys_path")"
  touch "$keys_path"
  chmod 600 "$keys_path"

  {
    echo "$KEY_COMMENT"
    cat "$tmpfile"
  } >> "$keys_path"

  printf '%s\n' "$pub_key"
  rm -rf "$tmpdir"
}

write_team_recipient() {
  local repo="$1"
  local key_name="$2"
  local pub_key="$3"
  local key_file="$repo/ops/keys/team/$key_name.pub"

  if [ "$DRY_RUN" = "1" ]; then
    info "Dry run: would write $pub_key to $key_file"
    return 0
  fi

  mkdir -p "$repo/ops/keys/team"
  printf '%s\n' "$pub_key" > "$key_file"
}

regenerate_sops_config() {
  local repo="$1"

  if [ "$DRY_RUN" = "1" ]; then
    info "Dry run: would regenerate .sops.yaml from sops.nix"
    return 0
  fi

  (cd "$repo" && nix eval --raw -f ./sops.nix yaml > .sops.yaml)
}

commit_and_push() {
  local repo="$1"
  local username="$2"
  local key_name="$3"

  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  git -C "$repo" --no-pager diff -- .sops.yaml "ops/keys/team/$key_name.pub" || true

  if [ "$COMMIT_CHANGES" != "1" ]; then
    info "Skipping commit."
    return 0
  fi

  if ! gum confirm "Commit recipient changes?"; then
    info "Skipping commit."
    return 0
  fi

  git -C "$repo" add .sops.yaml "ops/keys/team/$key_name.pub"
  if git -C "$repo" diff --cached --quiet; then
    info "No changes to commit."
    return 0
  fi

  git -C "$repo" commit -m "chore(secrets): add sops recipient for $username"

  if [ "$PUSH_CHANGES" = "1" ] && gum confirm "Push commit to trigger CI rekey?"; then
    git -C "$repo" push
    success "Pushed recipient change. CI will rekey encrypted secrets; pull again after it finishes."
  else
    info "Push skipped. Push this commit when you are ready for CI to rekey secrets."
  fi
}

main() {
  parse_args "$@"

  local repo username key_name keys_path pub_key

  repo="$(ensure_repo)"
  info "Using darkmatter/tools checkout: $repo"

  username="$(get_username)"
  key_name="${KEY_NAME:-$username}"
  keys_path="$(standard_age_keys_path)"

  ensure_team_recipient_available "$repo" "$key_name"

  info "Generating a new personal age identity for $username"
  pub_key="$(generate_age_identity "$keys_path")"
  info "Public recipient: $pub_key"

  write_team_recipient "$repo" "$key_name" "$pub_key"
  regenerate_sops_config "$repo"

  success "Added recipient ops/keys/team/$key_name.pub and regenerated .sops.yaml"
  commit_and_push "$repo" "$username" "$key_name"
}

main "$@"

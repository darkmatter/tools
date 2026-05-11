#!/usr/bin/env bash
# set -euo pipefail

RED=197
KIWI=156
PINK=212
# Foreground
PRIMARY=7
BRIGHT=15
# FAINT=238
FAINT=103
DARK=238

# echo "BASH_SOURCE[0]: ${BASH_SOURCE[0]}"

log() {
  if command -v gum >/dev/null 2>&1; then
    gum log --level="info" --time="1/2 15:04:05" --prefix="$LOG_PREFIX" -s "$@"
  else
    echo "$@"
  fi
}

debug() {
  if [ "${DEBUG:-0}" -eq 1 ]; then
    echo "$@" >> /tmp/debug.log
    # if command -v gum >/dev/null 2>&1; then
    #   gum log --level="debug" --time="1/2 15:04:05" --prefix="$LOG_PREFIX" -s "$@"
    # else
    #   echo "DEBUG: $@"
    # fi
  fi
}

is_cached() {
  local input_file=$1
  local actual_hash=$2
  touch "$CACHEFILE"
  saved=$(cat "$CACHEFILE" | grep "$input_file")
  if [ -z "$saved" ]; then
    log -l warn "No cache found for $input_file"
    return 1
  fi
  if [ "$actual_hash" != "$saved" ]; then
    log -l warn "Invalid cache $input_file"
    return 1
  fi
  return 0
}

autoinstall_hooks() {
  filepath=".pre-commit-config.yaml"
  checksum=$(sha256sum "$filepath")
  if is_cached "$filepath" "$checksum"; then
    # log -l debug "Pre-commit hooks are up to date."
    return
  fi
  if prek install; then
    log -l info "Pre-commit hooks installed successfully."
  else
    log -l error "Failed to install pre-commit hooks"
    exit 1
  fi
  grep -v "$filepath" "$CACHEFILE" > "${CACHEFILE}.tmp" && mv "${CACHEFILE}.tmp" "$CACHEFILE"
  echo "$checksum" >> "$CACHEFILE"
  log -l info "Pre-commit hooks installed."
}


find_root() {
  local root_path=$PWD
  local ws_file=./pnpm-workspace.yaml
  while ! [ -f "$ws_file" ]; do
    cd ..
    if [ "$(pwd)" == "/" ]; then break; fi
  done
  echo "$ws_file"
}

install_vault_cli() {
  if ! command -v aws-vault >/dev/null 2>&1; then

    gum style --foreground 212 "Installing vault..."
    if [[ ! $(uname -s) == "Darwin" ]]; then
      curl -fsSL "https://github.com/ByteNess/aws-vault/releases/download/v7.7.5/aws-vault-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)" --output /tmp/aws-vault
      mv /tmp/aws-vault "${root_path}/bin/aws-vault"
      chmod +x "$FLOX_ENV_PROJECT/bin/aws-vault"
    fi
    brew install -y aws-vault
  fi
}


container() {
  gum style \
    --border rounded --border-foreground 240 \
   --align center --width 70 --margin "12 2 2 4" --padding "0 0" \
     "$1"
}
container_status_indicator() {
  local service="$1"
  local state
  state=$(docker compose ps --format json | jq -r "select(.Service==\"$service\") | .State")
  fg_color=$RED
  if [ "$state" = "running" ]; then
    fg_color=$KIWI
  fi
  svc_name=$(gum style --foreground 240 "$service")
  sv_status=$(gum style --width 1 --height 1 --foreground $fg_color "●")
  echo "$svc_name $sv_status"
}

inner() {
  gum style \
    --border-foreground 240 --border none \
   --align left --width 68 --margin "1 0" --padding "0 6 2 6" \
     "$1"
}

txtmeta() {
  contents=$(gum style \
      --border-foreground 240 --border none \
   --align right --width 68 --foreground $DARK --padding "0 0" --margin "0 0 2 0" \
     "$1")
  echo "$contents"
  echo ""
}

screen_width() {
  tput cols || echo 80
}

fullscreen() {
  local h w
  h=$(tput lines)
  w=$(screen_width)
  ww=$((w - 2))
  hb=$((h - 12))
  gum style \
    --foreground 240 \
    --margin "0 0" \
    --width $ww --height $hb --align=center \
    "$1"
}

title() {
  gum style --bold --foreground $PINK "$1"
}

text() {
  gum style --foreground $PRIMARY "$1"
}

subtle() {
  gum style --foreground $FAINT "$1"
}


emphasize() {
  gum style --bold --foreground $BRIGHT "$1"
}

hr() {
  gum style --foreground 240 "============================================================================"
}

main() {
  pg_status=$(container_status_indicator "postgres")
  redis_status=$(container_status_indicator "redis")
  meta_el=$(txtmeta "$pg_status  $redis_status")
  tpl=$(cat <<'H'
{{ Foreground "212" (Bold "Dev Shell Activated") }}
{{ Foreground "103" (Faint "Your environment is ready") }}


{{ Foreground "7" `This repo uses nix-based tooling (flox) which provides a
consistent and reproducible dev environment. To enter the CLI menu, run `}}{{ Foreground "156" "x" }} {{ Foreground "7" `in your shell.` }}


{{ Foreground "7" "Get started by running one of the commands below. The credential-server should be run in its own shell:" }}

{{ Foreground "99" "Credential Server" }}
{{ Foreground "103" `  make ` }}{{ Foreground "156" "credential-server" }}

{{ Foreground "99" "Infrastructure" }}
{{ Foreground "103" `  make ` }}{{ Foreground "156" "<infra|workers|python-api>" }}

{{ Foreground "99" "Web/Mobile App" }}
{{ Foreground "103" `  make ` }}{{ Foreground "156" "dev" }}
H
)
  header_el=$(echo "$tpl" | gum format -t template)
  wrapped=$(inner "$header_el")

  # Render
  clear
  echo ""
  echo ""
  bodyel=$(container "$meta_el $wrapped")
  fullscreen "$bodyel" || true

  # install_vault_cli
  # autoinstall_hooks || echo ""
}




main

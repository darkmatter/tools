# Common library
#  Usage: source ${SCRIPT_DIR}/lib.sh

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
    die "$1 not found — run this via: nix run github:darkmatter/tools#rclone-drive-setup"
  fi
}


RED=197
KIWI=156 # 156
PINK=212 # 212
PURPLE=99 # 99
# Foreground
PRIMARY=7 # 7
BRIGHT=15
# FAINT=238
FAINT=103 # 103
DARK=0
GRAY=240
ORANGE=208
YELLOW=226
CYAN=6
BG="" #

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

container() {
  wh=$(tput lines)
  free_space=$((wh - 32))
  per_side=$((free_space / 2))
  if [ "$per_side" -lt 0 ]; then
    per_side=0
  fi
  gum style \
    --border rounded --border-foreground "$DARK" \
    --background "$BG" \
    --align center --width 70 --margin "$per_side 2 $per_side 4" --padding "0 0" \
     "$1"
}
# render a traffic light status indicator
# $1: service name
# $2: state 0=green, 1=red, 2=yellow, 3=cyan, 4=faint
status_indicator() {
  local service="$1"
  local state="$2"
  fg_color=$RED
  if [ "$state" -eq 0 ]; then
    fg_color=$KIWI
  elif [ "$state" -eq 1 ]; then
    fg_color=$RED
  elif [ "$state" -eq 2 ]; then
    fg_color=$CYAN
  elif [ "$state" -eq 3 ]; then
    fg_color=$ORANGE
  elif [ "$state" -eq 4 ]; then
    fg_color=$DARK
  fi
  svc_name=$(gum style --foreground "$GRAY"  "$service")
  sv_status=$(gum style --width 1 --height 1 --foreground $fg_color  "●" )
  echo "$svc_name $sv_status"
}

inner() {
  gum style \
    --border-foreground "$DARK" --border none \
    --background "$BG" \
    --align left --width 68 --margin "1 0" --padding "0 6 2 6" \
     "$1"
}

txtmeta() {
  gum style \
      --border-foreground "$DARK" --border none \
    --align right --width 68 --foreground $DARK --padding "0 0" --margin "0 0 2 0" \
     "$1"
  echo ""
}

screen_width() {
  tput cols || echo 80
}

fullscreen() {
  local h w
  h=$(tput lines)
  w=$(screen_width)
  ww=$(screen_width)
  hb=$(tput lines)
  # ww=$((w - 2))
  # hb=$((h - 12))
  gum style \
    --foreground "$GRAY" \
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



emphasize() {
  gum style --bold --foreground $BRIGHT "$1"
}

hr() {
  gum style --foreground "$GRAY" "============================================================================"
}


just_recipe_data() {
  just --color never --dump --dump-format json 2>/dev/null \
    | jq -r '
        def recipes:
          (.recipes // {} | to_entries[] | .value),
          (.modules // {} | to_entries[] | .value | recipes);

        def params:
          (.parameters // [])
          | map(
              if .kind == "variadic" then .name + "..."
              elif .default != null then "[" + .name + "]"
              else .name
              end
            )
          | join(" ");

        recipes
        | select(.private | not)
        | (.namepath | gsub("::"; " ")) as $recipe_name
        | params as $params
        | ($recipe_name + if $params == "" then "" else " " + $params end) as $recipe_command
        | [
            (.doc // .namepath),
            $recipe_name,
            $recipe_command
          ]
        | @tsv
      '
}

template_string() {
  jq -Rs .
}

render_just_recipe_template() {
  description="$(printf '%s' "$1" | template_string)"
  recipe_command="$(printf '%s' "$2" | template_string)"

  printf '{{ Foreground "62" %s }}\n' "$description"
  printf '{{ Foreground "103" `  just ` }}{{ Foreground "156" %s }}\n\n' "$recipe_command"
}

generate_just_recipe_template() {
  recipe_data="$1"
  shift

  if [ "$#" -eq 0 ]; then
    printf '%s\n' "$recipe_data" \
      | while IFS="$(printf '\t')" read -r description recipe_name recipe_command; do
        [ -n "$recipe_command" ] || continue
        render_just_recipe_template "$description" "$recipe_command"
      done
    return 0
  fi

  for requested_recipe in "$@"; do
    printf '%s\n' "$recipe_data" \
      | while IFS="$(printf '\t')" read -r description recipe_name recipe_command; do
        [ -n "$recipe_command" ] || continue
        if [ "$requested_recipe" = "$recipe_name" ] || [ "$requested_recipe" = "$recipe_command" ]; then
          render_just_recipe_template "$description" "$recipe_command"
          break
        fi
      done
  done
}

format_just_recipes() {
  recipe_data="$(just_recipe_data)"
  generate_just_recipe_template "$recipe_data" "$@" | gum format -t template
}

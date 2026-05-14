#!/usr/bin/env bash
set -euo pipefail

# Standalone Darkmatter-style welcome screen renderer.
#
# Configure with environment variables, or pass quick-start recipes as argv:
#
#   DARKMATTER_WELCOME_TITLE="Dev Shell Activated" \
#   DARKMATTER_WELCOME_QUICK_START_RECIPES=$'rclone setup\nrclone remotes\nrekey' \
#   ./ops/scripts/welcome-card.sh
#
#   ./ops/scripts/welcome-card.sh "rclone setup" "rclone remotes" rekey

title="${DARKMATTER_WELCOME_TITLE:-Dev Shell Activated}"
subtitle="${DARKMATTER_WELCOME_SUBTITLE:-Your environment is ready}"
description="${DARKMATTER_WELCOME_DESCRIPTION:-This repo uses nix-based tooling which provides a consistent and reproducible dev environment. To enter the main CLI menu, run: }"
status_name="${DARKMATTER_WELCOME_STATUS_NAME:-devshell}"
footer_description="${DARKMATTER_WELCOME_FOOTER_DESCRIPTION:-View all available commands}"
footer_command="${DARKMATTER_WELCOME_FOOTER_COMMAND:-just}"
width="${DARKMATTER_WELCOME_WIDTH:-70}"
inner_width="${DARKMATTER_WELCOME_INNER_WIDTH:-68}"
clear_screen="${DARKMATTER_WELCOME_CLEAR:-1}"
quick_start_recipes_text="${DARKMATTER_WELCOME_QUICK_START_RECIPES:-}"

export JUST_CHOOSER="${JUST_CHOOSER:-gum choose}"

quick_start_recipes=()
if [ "$#" -gt 0 ]; then
  quick_start_recipes=("$@")
elif [ -n "$quick_start_recipes_text" ]; then
  while IFS= read -r recipe; do
    [ -n "$recipe" ] || continue
    quick_start_recipes+=("$recipe")
  done <<< "$quick_start_recipes_text"
fi

if [ "$clear_screen" = "1" ] || [ "$clear_screen" = "true" ]; then
  clear || true
fi

if ! command -v gum >/dev/null 2>&1; then
  printf '%s\n%s\n\n%s%s\n' "$title" "$subtitle" "$description" "$footer_command"
  if command -v just >/dev/null 2>&1; then
    printf '\nAvailable commands:\n'
    just --list || true
  fi
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n%s\n\n%s%s\n' "$title" "$subtitle" "$description" "$footer_command"
  exit 0
fi

KIWI=156
GRAY=240
DARK=0
BG=""

screen_width() {
  tput cols 2>/dev/null || echo 80
}

screen_height() {
  tput lines 2>/dev/null || echo 40
}

status_indicator() {
  local service="$1"
  local state="${2:-0}"
  local fg_color="$KIWI"

  if [ "$state" -eq 1 ]; then
    fg_color=197
  elif [ "$state" -eq 2 ]; then
    fg_color=6
  elif [ "$state" -eq 3 ]; then
    fg_color=208
  elif [ "$state" -eq 4 ]; then
    fg_color="$DARK"
  fi

  local svc_name
  local svc_status
  svc_name=$(gum style --foreground "$GRAY" "$service")
  svc_status=$(gum style --width 1 --height 1 --foreground "$fg_color" "●")
  echo "$svc_name $svc_status"
}

container() {
  local terminal_height free_space per_side
  terminal_height=$(screen_height)
  free_space=$((terminal_height - 32))
  if [ "$free_space" -lt 0 ]; then
    free_space=0
  fi
  per_side=$((free_space / 2))

  gum style \
    --border rounded --border-foreground "$DARK" \
    --background "$BG" \
    --align center --width "$width" --margin "$per_side 2 $per_side 4" --padding "0 0" \
    "$1"
}

inner() {
  gum style \
    --border-foreground "$DARK" --border none \
    --background "$BG" \
    --align left --width "$inner_width" --margin "1 0" --padding "0 6 2 6" \
    "$1"
}

txtmeta() {
  gum style \
    --border-foreground "$DARK" --border none \
    --align right --width "$inner_width" --foreground "$DARK" --padding "0 0" --margin "0 0 2 0" \
    "$1"
  echo ""
}

fullscreen() {
  local w h
  w=$(screen_width)
  h=$(screen_height)
  gum style \
    --foreground "$GRAY" \
    --margin "0 0" \
    --width "$w" --height "$h" --align=center \
    "$1"
}

template_string() {
  jq -Rs .
}

render_just_recipe_template() {
  local recipe_description recipe_command
  recipe_description=$(printf '%s' "$1" | template_string)
  recipe_command=$(printf '%s' "$2" | template_string)

  printf '{{ Foreground "62" %s }}\n' "$recipe_description"
  if [ -z "$2" ]; then
    # shellcheck disable=SC2016
    printf '{{ Foreground "156" `  just` }}\n\n'
  else
    # shellcheck disable=SC2016
    printf '{{ Foreground "103" `  just ` }}{{ Foreground "156" %s }}\n\n' "$recipe_command"
  fi
}

just_recipe_data() {
  if ! command -v just >/dev/null 2>&1; then
    return 0
  fi

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
      ' || true
}

generate_just_recipe_template() {
  local recipe_data="$1"
  shift

  local count=0
  local max=3

  if [ "$#" -eq 0 ]; then
    while IFS="$(printf '\t')" read -r recipe_description _recipe_name recipe_command; do
      [ -n "$recipe_command" ] || continue
      if [ "$count" -ge "$max" ]; then
        break
      fi
      render_just_recipe_template "$recipe_description" "$recipe_command"
      count=$((count + 1))
    done <<< "$recipe_data"
    return 0
  fi

  for requested_recipe in "$@"; do
    if [ "$count" -ge "$max" ]; then
      break
    fi
    while IFS="$(printf '\t')" read -r recipe_description recipe_name recipe_command; do
      [ -n "$recipe_command" ] || continue
      if [ "$requested_recipe" = "$recipe_name" ] || [ "$requested_recipe" = "$recipe_command" ]; then
        render_just_recipe_template "$recipe_description" "$recipe_command"
        count=$((count + 1))
        break
      fi
    done <<< "$recipe_data"
  done
}

format_just_recipes() {
  local recipe_data
  recipe_data="$(just_recipe_data)"
  generate_just_recipe_template "$recipe_data" "${quick_start_recipes[@]}" | gum format -t template
}

nix_state() {
  if [ -n "${IN_NIX_SHELL:-}" ]; then
    echo 0
  else
    echo 1
  fi
}

title_template=$(printf '%s' "$title" | template_string)
subtitle_template=$(printf '%s' "$subtitle" | template_string)
description_template=$(printf '%s' "$description" | template_string)
footer_command_template=$(printf '%s' "$footer_command" | template_string)

header_template=$(printf '%s\n' \
  "{{ Foreground \"212\" (Bold $title_template) }}" \
  "{{ Foreground \"103\" (Faint $subtitle_template) }}" \
  "" \
  "{{ Foreground \"#dddddd\" $description_template }}{{ Color \"156\" \"235\" (Bold $footer_command_template) }}" \
  "" \
  "" \
  "{{ Foreground \"#888888\" \"Quick Start:\" }}" \
  "{{ Foreground \"0\" \"\" }}")

flake_state=$(nix_state)
flake_status=$(status_indicator "$status_name" "$flake_state")
meta_el=$(txtmeta "$flake_status")
header_el=$(echo "$header_template" | gum format -t template)
recipes_el=$(format_just_recipes)
footer_el=$(render_just_recipe_template "$footer_description" "" | gum format -t template)

wrapped=$(inner "$(printf '%s\n%s\n\n%s' "$header_el" "$recipes_el" "$footer_el")")
body_el=$(container "$meta_el $wrapped")

echo ""
echo ""
fullscreen "$body_el" || true

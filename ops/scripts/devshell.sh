# Shared devshell environment for this repository.
GIT_ROOT="$(git rev-parse --show-toplevel)"

source "$GIT_ROOT/ops/scripts/lib.sh"

# Check dependencies, install if missing
check_cmd gum
check_cmd jq

export SOPS_KEYSERVICE="${SOPS_KEYSERVICE:-tcp://sops-keyservice.tail6277a6.ts.net:5000}"
export JUST_CHOOSER="${JUST_CHOOSER:-gum choose}"

clear

nix_state() {
  if [ -n "${IN_NIX_SHELL:-}" ]; then
    echo 0
  else
    echo 1
  fi
}

main() {
  flake_state=$(nix_state)
  flake_status=$(status_indicator "devshell" "$flake_state")
  meta_el=$(txtmeta "$flake_status")
  tpl=$(cat <<'H'
{{ Foreground "212" (Bold "Dev Shell Activated") }}
{{ Foreground "103" (Faint "Your environment is ready") }}

{{ Foreground "#dddddd" `This repo uses nix-based tooling which provides a consistent and reproducible dev environment. To enter the main CLI menu, run: `}}{{ Color "156" "235" (Bold "just") }}


{{ Foreground "#888888" "Quick Start:" }}
{{ Foreground "0" "" }}
H
)
  header_el=$(echo "$tpl" | gum format -t template)
  recipes_el=$(format_just_recipes "rclone setup"  "rclone remotes" "gen recipients" rekey)
  footer_el=$(render_just_recipe_template "View all available commands" "" | gum format -t template)

  wrapped=$(inner "$(printf '%s\n%s\n\n%s' "$header_el" "$recipes_el" "$footer_el")")

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

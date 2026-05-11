#!/usr/bin/env bash
# Install, inspect, or remove a macOS LaunchAgent that mounts the shared
# Darkmatter Google Drive with rclone at user login.

set -euo pipefail

LABEL="${DARKMATTER_RCLONE_LAUNCH_AGENT_LABEL:-com.darkmatter.rclone-drive}"
FLAKE_REF="${DARKMATTER_RCLONE_FLAKE_REF:-github:darkmatter/nix}"
SOPS_KEYSERVICE="${SOPS_KEYSERVICE:-tcp://sops-keyservice.tail6277a6.ts.net:5000}"
DEFAULT_MOUNT_DIR="$HOME/darkmatter/shared"
DEFAULT_REMOTE="darkmatter-google-drive"

usage() {
  cat >&2 <<EOF
Usage: rclone-drive-launch-agent [install|uninstall|status] [mount-dir] [remote]

Examples:
  rclone-drive-launch-agent install
  rclone-drive-launch-agent install ~/darkmatter/shared darkmatter-google-drive
  rclone-drive-launch-agent uninstall
  rclone-drive-launch-agent status

Environment:
  DARKMATTER_RCLONE_FLAKE_REF       Flake to run. Default: github:darkmatter/nix
  DARKMATTER_RCLONE_LAUNCH_AGENT_LABEL
                                    LaunchAgent label. Default: com.darkmatter.rclone-drive
  SOPS_KEYSERVICE                   SOPS keyservice URL.
EOF
}

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

xml_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&apos;/g"
}

require_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "LaunchAgents are only supported on macOS." >&2
    exit 1
  fi
}

bootstrap_target() {
  printf 'gui/%s\n' "$(id -u)"
}

agent_paths() {
  support_dir="$HOME/Library/Application Support/Darkmatter"
  launch_agents_dir="$HOME/Library/LaunchAgents"
  wrapper_path="$support_dir/rclone-drive-launch-agent.sh"
  plist_path="$launch_agents_dir/$LABEL.plist"
  stdout_log="$HOME/Library/Logs/darkmatter-rclone-drive.log"
  stderr_log="$HOME/Library/Logs/darkmatter-rclone-drive.err.log"
}

install_agent() {
  local mount_dir="${1:-$DEFAULT_MOUNT_DIR}"
  local remote="${2:-$DEFAULT_REMOTE}"
  local nix_bin
  local target

  require_macos
  agent_paths

  mount_dir="$(expand_path "$mount_dir")"

  if ! nix_bin="$(command -v nix)"; then
    echo "nix was not found in PATH. Install Nix before installing the LaunchAgent." >&2
    exit 1
  fi

  mkdir -p "$support_dir" "$launch_agents_dir" "$(dirname "$stdout_log")" "$mount_dir"

  cat > "$wrapper_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export SOPS_KEYSERVICE="$SOPS_KEYSERVICE"
exec "$nix_bin" run "$FLAKE_REF#rclone-drive" -- "$mount_dir" "$remote"
EOF
  chmod 755 "$wrapper_path"

  wrapper_xml="$(printf '%s' "$wrapper_path" | xml_escape)"
  stdout_xml="$(printf '%s' "$stdout_log" | xml_escape)"
  stderr_xml="$(printf '%s' "$stderr_log" | xml_escape)"
  label_xml="$(printf '%s' "$LABEL" | xml_escape)"

  cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label_xml</string>

  <key>ProgramArguments</key>
  <array>
    <string>$wrapper_xml</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>ThrottleInterval</key>
  <integer>30</integer>

  <key>StandardOutPath</key>
  <string>$stdout_xml</string>

  <key>StandardErrorPath</key>
  <string>$stderr_xml</string>
</dict>
</plist>
EOF

  plutil -lint "$plist_path" >/dev/null

  target="$(bootstrap_target)"
  launchctl bootout "$target" "$plist_path" >/dev/null 2>&1 || true
  launchctl bootstrap "$target" "$plist_path"
  launchctl enable "$target/$LABEL"
  launchctl kickstart -k "$target/$LABEL"

  echo "Installed and started LaunchAgent: $LABEL"
  echo "Mount: $mount_dir"
  echo "Remote: $remote"
  echo "Plist: $plist_path"
  echo "Logs: $stdout_log and $stderr_log"
}

uninstall_agent() {
  local target

  require_macos
  agent_paths

  target="$(bootstrap_target)"
  launchctl bootout "$target" "$plist_path" >/dev/null 2>&1 || true
  rm -f "$plist_path" "$wrapper_path"

  echo "Removed LaunchAgent: $LABEL"
}

status_agent() {
  local target

  require_macos
  agent_paths

  target="$(bootstrap_target)"
  if launchctl print "$target/$LABEL" >/dev/null 2>&1; then
    launchctl print "$target/$LABEL"
  else
    echo "LaunchAgent is not loaded: $LABEL"
    [ -e "$plist_path" ] && echo "Plist exists: $plist_path"
  fi
}

command="${1:-install}"
case "$command" in
  install)
    shift || true
    install_agent "$@"
    ;;
  uninstall|remove)
    uninstall_agent
    ;;
  status)
    status_agent
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 64
    ;;
esac

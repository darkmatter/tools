mod gen 'ops/just/gen.justfile'
mod rclone 'ops/just/rclone.justfile'

# List all available recipes
default:
    just --list

# ── Key generation ─────────────────────────────────────────────────────────────

# Fetch age keys from GitHub for every org member → keys/generated/recipients.json
gen-recipients:
    just gen recipients

# Regenerate .sops.yaml from keys/default.nix + generated recipients + keys/team/
rekey:
    #!/usr/bin/env bash
    set -euo pipefail
    nix eval --raw -f ./sops.nix yaml > .sops.yaml
    echo "Wrote .sops.yaml"
    echo "Now run: sops updatekeys ops/secrets/rclone-config.sops.yaml"

# ── rclone shortcuts ──────────────────────────────────────────────────────────

# Install the darkmatter team Google Drive
install-drive:
    just rclone setup

# Install a macOS LaunchAgent to automount the shared Google Drive at login.
install-drive-automount:
    just rclone launch-agent-install

# Show the macOS LaunchAgent status for the shared Google Drive automount.
drive-automount-status:
    just rclone launch-agent-status

# Remove the macOS LaunchAgent for the shared Google Drive automount.
uninstall-drive-automount:
    just rclone launch-agent-uninstall

# Unmount a mounted drive path.
rclone-unmount path:
    just rclone unmount {{ path }}

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

# Run the interactive Google Drive setup wizard.
rclone-setup:
    just rclone setup

# Mount the shared Google Drive at the default path.
rclone-mount:
    just rclone mount

# Mount the personal Google Drive at the default path.
rclone-mount-personal:
    just rclone mount-personal

# Unmount a mounted drive path.
rclone-unmount path:
    just rclone unmount {{ path }}

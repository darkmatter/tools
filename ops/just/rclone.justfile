# Google Drive rclone helpers

# Run the interactive Google Drive setup wizard.
setup:
    nix run .#rclone-drive-setup

# Mount the shared Google Drive at the default path.
mount:
    nix run .#rclone-drive -- ~/darkmatter/shared

# Mount the shared Google Drive at a custom path.
mount-at path:
    nix run .#rclone-drive -- {{ path }}

# Mount a specific shared Google Drive remote path at a custom local path.

# Example: just rclone mount-remote ~/Drive darkmatter-google-drive:Shared
mount-remote path remote:
    nix run .#rclone-drive -- {{ path }} {{ remote }}

# Mount the default shared Google Drive path used by the setup wizard.
mount-shared:
    nix run .#rclone-drive -- ~/darkmatter/shared darkmatter-google-drive

# Open the local personal rclone config flow.

# The setup wizard normally handles this, but this is useful for reconfiguring the personal remote manually.
personal-config:
    nix shell nixpkgs#rclone -c rclone --config ~/.config/rclone/rclone.conf config create darkmatter-personal drive scope drive

# Mount the personal Google Drive remote at the default path for the current user.
mount-personal:
    RCLONE_CONFIG=~/.config/rclone/rclone.conf nix run .#rclone-drive -- ~/darkmatter/$USER darkmatter-personal

# Mount the personal Google Drive remote at a custom path.
mount-personal-at path:
    RCLONE_CONFIG=~/.config/rclone/rclone.conf nix run .#rclone-drive -- {{ path }} darkmatter-personal

# Show configured local rclone remotes.
remotes:
    nix shell nixpkgs#rclone -c rclone listremotes

# Unmount a mounted drive path.

# macOS usually uses `umount`; Linux users may prefer `fusermount3 -u`.
unmount path:
    umount {{ path }}

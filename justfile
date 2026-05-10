mod gen 'ops/just/gen.justfile'
mod rclone 'ops/just/rclone.justfile'

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

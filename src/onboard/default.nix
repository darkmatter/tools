{
  pkgs,
  rcloneDriveSetup,
  rcloneDriveLaunchAgent,
}:
pkgs.writeShellApplication {
  name = "darkmatter";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.git
    pkgs.gum
    pkgs.nix
  ];
  text = ''
    set -euo pipefail
    export DARKMATTER_RCLONE_DRIVE_SETUP_BIN="${rcloneDriveSetup}/bin/rclone-drive-setup"
    export DARKMATTER_RCLONE_DRIVE_LAUNCH_AGENT_BIN="${rcloneDriveLaunchAgent}/bin/rclone-drive-launch-agent"
    exec ${pkgs.bash}/bin/bash ${./onboard.sh} "$@"
  '';
}

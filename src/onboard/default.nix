{
  pkgs,
  rcloneDriveSetup,
  rcloneDriveLaunchAgent,
  sopsJoin,
}:
pkgs.writeShellApplication {
  name = "darkmatter";
  meta.description = "Darkmatter onboarding and setup tool";
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
    export DARKMATTER_SOPS_JOIN_BIN="${sopsJoin}/bin/sops-join"
    exec ${pkgs.bash}/bin/bash ${./onboard.sh} "$@"
  '';
}

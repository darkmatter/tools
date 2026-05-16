{ pkgs }:
let
  rcloneGoogleDrive = pkgs.writeShellApplication {
    name = "rclone-google-drive";
    meta.description = "Mount and manage Google Drive via rclone";
    runtimeInputs = [
      pkgs.rclone
      pkgs.coreutils
      pkgs.sops
    ];
    text = ''
      set -euo pipefail
      export DARKMATTER_RCLONE_SOPS_FILE="${../../ops/secrets/rclone-config.sops.yaml}"
      exec ${pkgs.bash}/bin/bash ${./gdrive.sh} "$@"
    '';
  };
  rcloneDriveSetup = pkgs.writeShellApplication {
    name = "rclone-drive-setup";
    meta.description = "Setup Google Drive rclone mount";
    runtimeInputs = [
      pkgs.rclone
      pkgs.coreutils
      pkgs.sops
      pkgs.gum
      pkgs.gnugrep
    ];
    text = ''
      set -euo pipefail
      export DARKMATTER_RCLONE_SOPS_FILE="${../../ops/secrets/rclone-config.sops.yaml}"
      export DARKMATTER_RCLONE_LAUNCH_AGENT_SCRIPT="${./launch-agent.sh}"
      exec ${pkgs.bash}/bin/bash ${./setup.sh} "$@"
    '';
  };
  rcloneDriveLaunchAgent = pkgs.writeShellApplication {
    name = "rclone-drive-launch-agent";
    meta.description = "macOS LaunchAgent for rclone Google Drive";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      set -euo pipefail
      exec ${pkgs.bash}/bin/bash ${./launch-agent.sh} "$@"
    '';
  };
in
{
  inherit rcloneGoogleDrive rcloneDriveSetup rcloneDriveLaunchAgent;
}

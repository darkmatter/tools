{ self, ... }:
{
  perSystem =
    { config, ... }:
    let
      inherit (config.packages)
        darkmatter
        rclone-drive
        rclone-drive-setup
        rclone-drive-launch-agent
        sops
        sops-join
        dm
        welcome
        ;
    in
    {
      apps = {
        default = {
          type = "app";
          program = "${darkmatter}/bin/darkmatter";
          meta.description = "Darkmatter onboarding and setup tool";
        };
        darkmatter = {
          type = "app";
          program = "${darkmatter}/bin/darkmatter";
          meta.description = "Darkmatter onboarding and setup tool";
        };
        rclone-drive = {
          type = "app";
          program = "${rclone-drive}/bin/rclone-google-drive";
          meta.description = "Mount and manage Google Drive via rclone";
        };
        rclone-drive-setup = {
          type = "app";
          program = "${rclone-drive-setup}/bin/rclone-drive-setup";
          meta.description = "Setup Google Drive rclone mount";
        };
        rclone-drive-launch-agent = {
          type = "app";
          program = "${rclone-drive-launch-agent}/bin/rclone-drive-launch-agent";
          meta.description = "macOS LaunchAgent for rclone Google Drive";
        };
        sops = {
          type = "app";
          program = "${sops}/bin/sops";
          meta.description = "Wrapper for sops with Darkmatter keyservice";
        };
        sops-join = {
          type = "app";
          program = "${sops-join}/bin/sops-join";
          meta.description = "Self-service SOPS recipient onboarding";
        };
        dm = {
          type = "app";
          program = "${dm}/bin/dm";
          meta.description = "The dm command";
        };
        welcome = {
          type = "app";
          program = "${welcome}/bin/darkmatter-welcome";
          meta.description = "Display the Darkmatter welcome card";
        };
      };
    };
}

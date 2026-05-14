{ self, ... }:
{
  perSystem =
    { config, ... }:
    let
      inherit (config.packages)
        darkmatter
        rclone-google-drive
        rclone-drive-setup
        rclone-drive-launch-agent
        sops
        dm
        welcome
        ;
    in
    {
      apps = {
        default = {
          type = "app";
          program = "${darkmatter}/bin/darkmatter";
        };
        darkmatter = {
          type = "app";
          program = "${darkmatter}/bin/darkmatter";
        };
        rclone-google-drive = {
          type = "app";
          program = "${rclone-google-drive}/bin/rclone-google-drive";
        };
        rclone-drive = {
          type = "app";
          program = "${rclone-google-drive}/bin/rclone-google-drive";
        };
        rclone-drive-setup = {
          type = "app";
          program = "${rclone-drive-setup}/bin/rclone-drive-setup";
        };
        rclone-drive-launch-agent = {
          type = "app";
          program = "${rclone-drive-launch-agent}/bin/rclone-drive-launch-agent";
        };
        sops = {
          type = "app";
          program = "${sops}/bin/sops";
        };
        dm = {
          type = "app";
          program = "${dm}/bin/dm";
        };
        welcome = {
          type = "app";
          program = "${welcome}/bin/darkmatter-welcome";
        };
      };
    };
}

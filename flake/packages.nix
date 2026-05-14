{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      rclone = pkgs.callPackage ../src/rclone { };
      onboard = pkgs.callPackage ../src/onboard {
        inherit (rclone) rcloneDriveSetup rcloneDriveLaunchAgent;
      };
      sopsWrapper = pkgs.callPackage ../src/sops { };
      welcome = pkgs.callPackage ../src/welcome { };
      dm = pkgs.callPackage ../src/dm { };
    in
    {
      packages = {
        default = onboard;
        darkmatter = onboard;
        rclone-google-drive = rclone.rcloneGoogleDrive;
        rclone-drive = rclone.rcloneGoogleDrive;
        rclone-drive-setup = rclone.rcloneDriveSetup;
        rclone-drive-launch-agent = rclone.rcloneDriveLaunchAgent;
        sops = sopsWrapper;
        inherit dm welcome;
      };
    };
}

{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      rclone = pkgs.callPackage ../src/rclone { };
      sopsWrapper = pkgs.callPackage ../src/sops { };
      sopsJoin = pkgs.callPackage ../src/sops-join { };
      onboard = pkgs.callPackage ../src/onboard {
        inherit (rclone) rcloneDriveSetup rcloneDriveLaunchAgent;
        inherit sopsJoin;
      };
      welcome = pkgs.callPackage ../src/welcome { };
      dm = pkgs.callPackage ../src/dm { };
    in
    {
      packages = {
        default = onboard;
        darkmatter = onboard;
        rclone-drive = rclone.rcloneGoogleDrive;
        rclone-drive-setup = rclone.rcloneDriveSetup;
        rclone-drive-launch-agent = rclone.rcloneDriveLaunchAgent;
        sops = sopsWrapper;
        sops-join = sopsJoin;
        inherit dm welcome;
      };
    };
}

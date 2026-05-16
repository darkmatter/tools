{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "sops-join";
  meta.description = "Self-service SOPS recipient onboarding for darkmatter/tools";

  runtimeInputs = [
    pkgs.age
    pkgs.coreutils
    pkgs.gh
    pkgs.git
    pkgs.gum
    pkgs.nix
  ];

  text = ''
    exec ${pkgs.bash}/bin/bash ${./sops-join.sh} "$@"
  '';
}

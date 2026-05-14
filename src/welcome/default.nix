{ pkgs }:
pkgs.writeShellApplication {
  name = "darkmatter-welcome";
  runtimeInputs = [
    pkgs.gum
    pkgs.jq
    pkgs.just
  ];
  text = builtins.readFile ./welcome-card.sh;
}

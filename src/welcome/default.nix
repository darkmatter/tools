{ pkgs }:
pkgs.writeShellApplication {
  name = "darkmatter-welcome";
  meta.description = "Display the Darkmatter welcome card";
  runtimeInputs = [
    pkgs.gum
    pkgs.jq
    pkgs.just
  ];
  text = builtins.readFile ./welcome-card.sh;
}

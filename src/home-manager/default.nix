{ darkmatter-agents }:

{
  imports = [
    (import ./agents.nix { inherit darkmatter-agents; })
  ];
}

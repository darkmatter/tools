# Flake-parts modules - import these at the flake level
# These modules are generic and don't require devenv. They work with
# any flake-parts based flake.
#
# Usage in consuming flakes:
#   # flake.nix
#   inputs.darkmatter.url = "github:darkmatter/devshell";
#
#   outputs = inputs@{ flake-parts, ... }:
#     flake-parts.lib.mkFlake { inherit inputs; } {
#       imports = [ inputs.darkmatter.flakeModules.default ];
#       # or individual modules:
#       # imports = [ inputs.darkmatter.flakeModules.agenix-rekey ];
#     };
#
{...}: {
  imports = [
    ./ci
    ./r2.nix
  ];
}

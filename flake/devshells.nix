{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.gum
          pkgs.jq
          pkgs.just
        ];
        shellHook = ''
          export DARKMATTER_DEVSHELL_LIB=${../src/devshell/lib.sh}
          source ${../src/devshell/devshell.sh}
        '';
      };
    };
}

{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "dm";

  runtimeInputs = [
    pkgs.nix
  ];

  text = ''
    cmd="''${1:-}"

    if [ -z "$cmd" ]; then
      echo "usage: dm <command> [args...]" >&2
      exit 2
    fi

    shift

    case "$cmd" in
      sop)
        cmd=sops
        ;;
    esac

    exec nix run "github:darkmatter/tools#$cmd" -- "$@"
  '';
}

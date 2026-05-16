{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "dm"; meta.description = "The dm command";

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
      sops-join|join-secrets|join-sops)
        cmd=sops-join
        ;;
    esac

    exec nix run "github:darkmatter/tools#$cmd" -- "$@"
  '';
}

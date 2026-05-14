{ pkgs }:
pkgs.writeShellApplication {
  name = "sops";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gnused
    pkgs.sops
  ];
  text = ''
    SOPS_AGE_RECIPIENTS="age16wuzuxnkcgfuxzvzgk5e5a5f6hhs386adjewyv54m9esr4yj6uuslpn6tp" \
    SOPS_KEYSERVICE="tcp://sops-keyservice.tail6277a6.ts.net:5000" \
    sops "$@"
  '';
}

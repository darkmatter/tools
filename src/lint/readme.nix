{pkgs, ...}: pkgs.buildNpmPackage {
  pname = "remark-readme";
  version = "0.1.0";
  src = ./remark-readme;
  npmDepsHash = "sha256-p3YusIhKzxh0vgxT0sQQrW6I2Gb8KeXs1BVkrxLcgxg=";
  dontNpmBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r node_modules $out/
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/lint-readme \
      --add-flags "$out/node_modules/remark-cli/cli.js" \
      --add-flags "--rc-path" \
      --add-flags "${pkgs.writeText "remarkrc.json" (builtins.toJSON {
        plugins = [ "standard-readme-preset" ];
      })}"
  '';
  nativeBuildInputs = [ pkgs.makeWrapper ];
}

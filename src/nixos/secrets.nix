{ agenix }:
{
  config,
  lib,
  ...
}:
let
  cfg = config.darkmatter.secrets;
  agenixSecrets = {
    openai-api-key = ../../secrets/openai-api-key.age;
  };
in
{
  imports = [
    agenix.nixosModules.default
  ];

  options.darkmatter.secrets = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Darkmatter shared agenix secrets.";
    };

    names = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (lib.attrNames agenixSecrets));
      default = lib.attrNames agenixSecrets;
      description = "Darkmatter agenix secret names to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets = lib.genAttrs cfg.names (name: {
      file = agenixSecrets.${name};
    });

    environment.variables = {
      SOPS_KEYSERVICE = "tcp://sops-keyservice.tail6277a6.ts.net:5000";
    };
  };
}

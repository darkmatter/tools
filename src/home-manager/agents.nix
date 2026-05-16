{ darkmatter-agents }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.darkmatter.agentSkills;

  # When the user opts out of HM installing opencode, substitute a
  # tiny stub derivation. This sidesteps an upstream HM bug where
  # `programs.opencode.package = null` crashes the warnings block —
  # it calls `lib.versionAtLeast` on a null version. The stub's
  # only job is to satisfy `lib.getVersion` and produce an empty
  # output so PATH isn't shadowed.
  opencodeStub =
    (pkgs.runCommand "opencode-stub" {
      meta.mainProgram = "opencode";
    } "mkdir -p $out")
    // {
      version = "1.2.15";
    };
in
{
  imports = [
    darkmatter-agents.homeManagerModules.default
  ];

  options.darkmatter.agentSkills = {
    personalPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "/Users/me/.config/darkmatter/skills";
      description = "Optional private skills directory to install with the personal id prefix.";
    };

    opencode.installPackage = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether the OpenCode preset should add `pkgs.opencode` to
        `home.packages`. Set to `false` if you manage the opencode
        binary outside Home Manager (Homebrew, manual install, etc).
        OpenCode config files and skills are installed either way.
      '';
    };
  };

  config = {
    _module.args.personalAgentSkillsPath = cfg.personalPath;

    programs.agent-skills.enable = lib.mkDefault true;

    programs.opencode.package = lib.mkIf (!cfg.opencode.installPackage) opencodeStub;
  };
}

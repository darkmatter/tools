{ darkmatter-agents }:
{
  config,
  lib,
  ...
}:
let
  cfg = config.darkmatter.agentSkills;
in
{
  imports = [
    darkmatter-agents.homeManagerModules.default
  ];

  options.darkmatter.agentSkills.personalPath = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    example = lib.literalExpression "/Users/me/.config/darkmatter/skills";
    description = "Optional private skills directory to install with the personal id prefix.";
  };

  config = {
    _module.args.personalAgentSkillsPath = cfg.personalPath;

    programs.agent-skills.enable = lib.mkDefault true;
  };
}

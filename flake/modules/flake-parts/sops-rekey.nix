{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  inherit (flake-parts-lib) mkPerSystemOption;
in
{
  options.perSystem = mkPerSystemOption (
    { config, ... }:
    {
      options.darkmatter.ci.sops-rekey = {
        enable = mkEnableOption "GitHub Actions workflow for automatic sops rekeying";

        branches = mkOption {
          type = types.listOf types.str;
          default = [ "main" ];
          description = "Branches to trigger rekey on";
        };

        triggerPaths = mkOption {
          type = types.listOf types.str;
          default = [ ".sops.yaml" ];
          description = "Paths that trigger the rekey workflow";
        };

        secretsDir = mkOption {
          type = types.str;
          default = ".";
          description = "Directory containing the secrets to rekey";
        };

        runsOn = mkOption {
          type = types.str;
          default = "ubuntu-latest";
          description = "GitHub Actions runner to use";
        };

        sshKeySecret = mkOption {
          type = types.str;
          default = "SOPS_SSH_KEY";
          description = "Name of the GitHub secret containing the CI SSH private key";
        };

        cachix = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable Cachix caching in the workflow";
          };

          name = mkOption {
            type = types.str;
            default = "";
            description = "Cachix cache name";
          };

          authTokenSecret = mkOption {
            type = types.str;
            default = "CACHIX_AUTH_TOKEN";
            description = "Name of the GitHub secret containing the Cachix auth token";
          };
        };
      };

      config = lib.mkIf config.darkmatter.ci.sops-rekey.enable {
        githubActions.enable = true;
        githubActions.workflows.sops-rekey = {
          name = "Rekey SOPS Secrets";

          on = {
            push = {
              branches = config.darkmatter.ci.sops-rekey.branches;
              paths = config.darkmatter.ci.sops-rekey.triggerPaths;
            };
            workflowDispatch = { };
          };

          permissions = {
            contents = "write";
          };

          jobs = {
            rekey = {
              runsOn = config.darkmatter.ci.sops-rekey.runsOn;
              steps = [
                {
                  name = "Checkout";
                  uses = "actions/checkout@v4";
                }
                {
                  name = "Install Nix";
                  uses = "cachix/install-nix-action@v30";
                  with_ = {
                    github_access_token = "\${{ secrets.GITHUB_TOKEN }}";
                  };
                }
              ]
              ++ lib.optional config.darkmatter.ci.sops-rekey.cachix.enable {
                name = "Setup Cachix";
                uses = "cachix/cachix-action@v15";
                with_ = {
                  name = config.darkmatter.ci.sops-rekey.cachix.name;
                  authToken = "\${{ secrets.${config.darkmatter.ci.sops-rekey.cachix.authTokenSecret} }}";
                };
              }
              ++ [
                {
                  name = "Setup SSH key for sops";
                  run = "mkdir -p ~/.ssh && echo \"\${{ secrets.${config.darkmatter.ci.sops-rekey.sshKeySecret} }}\" > ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519";
                }
                {
                  name = "Install sops";
                  run = "nix profile install nixpkgs#sops";
                }
                {
                  name = "Rekey secrets";
                  run = ''
                    find ${config.darkmatter.ci.sops-rekey.secretsDir} -type f \( -name "*.yaml" -o -name "*.json" -o -name "*.env" -o -name "*.ini" \) | while read -r file; do
                      if grep -q "sops:" "$file"; then
                        echo "Rekeying $file"
                        sops updatekeys -y "$file"
                      fi
                    done
                  '';
                }
                {
                  name = "Commit and push changes";
                  run = lib.concatStringsSep " && " [
                    ''git config user.name "github-actions[bot]"''
                    ''git config user.email "github-actions[bot]@users.noreply.github.com"''
                    ''git diff --quiet || (git add . && git commit -m "chore(secrets): rekey sops secrets" && git push)''
                  ];
                }
              ];
            };
          };
        };
      };
    }
  );
}

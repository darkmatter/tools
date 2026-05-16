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
          default = [
            ".sops.yaml"
            "sops.nix"
            "ops/keys/**"
          ];
          description = "Paths that trigger the rekey workflow";
        };

        secretsDir = mkOption {
          type = types.str;
          default = ".";
          description = "Directory containing the secrets to rekey";
        };

        rekeyFiles = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Specific encrypted files to rekey. Empty means discover every tracked file containing a sops metadata block.";
        };

        runsOn = mkOption {
          type = types.str;
          default = "ubuntu-latest";
          description = "GitHub Actions runner to use";
        };

        ageKeySecret = mkOption {
          type = types.str;
          default = "SOPS_AGE_KEY";
          description = "Name of the GitHub secret containing an age identity that can decrypt current SOPS files";
        };

        sshKeySecret = mkOption {
          type = types.str;
          default = "SOPS_SSH_KEY";
          description = "Deprecated fallback: name of the GitHub secret containing a CI SSH private key usable as an age identity";
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

      config = lib.mkIf config.darkmatter.ci.sops-rekey.enable (
        let
          ageKeySecretExpr = "\${{ secrets.${config.darkmatter.ci.sops-rekey.ageKeySecret} }}";
          sshKeySecretExpr = "\${{ secrets.${config.darkmatter.ci.sops-rekey.sshKeySecret} }}";
          workflowFilesInputExpr = "\${{ github.event.inputs.files }}";
        in
        {
        githubActions.enable = true;
        githubActions.workflows.sops-rekey = {
          name = "Rekey SOPS Secrets";

          on = {
            push = {
              branches = config.darkmatter.ci.sops-rekey.branches;
              paths = config.darkmatter.ci.sops-rekey.triggerPaths;
            };
            workflowDispatch = {
              inputs = {
                files = {
                  description = "Whitespace-separated encrypted files to rekey. Leave blank to discover all SOPS files.";
                  required = false;
                  default = lib.concatStringsSep " " config.darkmatter.ci.sops-rekey.rekeyFiles;
                };
              };
            };
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
                  name = "Configure SOPS identity";
                  run = ''
                    set -euo pipefail

                    mkdir -p "$HOME/.config/sops/age" "$HOME/.ssh"

                    if [ -n "${ageKeySecretExpr}" ]; then
                      printf '%s\n' "${ageKeySecretExpr}" > "$HOME/.config/sops/age/keys.txt"
                      chmod 600 "$HOME/.config/sops/age/keys.txt"
                      echo "SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt" >> "$GITHUB_ENV"
                    elif [ -n "${sshKeySecretExpr}" ]; then
                      printf '%s\n' "${sshKeySecretExpr}" > "$HOME/.ssh/id_ed25519"
                      chmod 600 "$HOME/.ssh/id_ed25519"
                    else
                      echo "Missing '${config.darkmatter.ci.sops-rekey.ageKeySecret}' repository secret." >&2
                      echo "Add an age identity that can decrypt the current secrets so CI can rekey for new recipients." >&2
                      exit 1
                    fi
                  '';
                }
                {
                  name = "Regenerate SOPS config";
                  run = ''
                    set -euo pipefail
                    nix eval --raw -f ./sops.nix yaml > .sops.yaml
                  '';
                }
                {
                  name = "Rekey secrets";
                  env = {
                    INPUT_FILES = workflowFilesInputExpr;
                  };
                  run = ''
                    set -euo pipefail

                    files="$INPUT_FILES"
                    if [ -z "$files" ]; then
                      files="${lib.concatStringsSep " " config.darkmatter.ci.sops-rekey.rekeyFiles}"
                    fi

                    if [ -z "$files" ]; then
                      files="$(git grep -l "sops:" -- ${config.darkmatter.ci.sops-rekey.secretsDir} '*.yaml' '*.yml' '*.json' '*.env' '*.ini' 2>/dev/null || true)"
                    fi

                    if [ -z "$files" ]; then
                      echo "No SOPS encrypted files found."
                      exit 0
                    fi

                    for file in $files; do
                      if [ ! -f "$file" ]; then
                        echo "Encrypted file not found: $file" >&2
                        exit 1
                      fi

                      echo "Rekeying $file"
                      nix run nixpkgs#sops -- updatekeys -y "$file"
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
        }
      );
    }
  );
}

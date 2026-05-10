# Agenix secrets configuration
# This file defines which public keys can decrypt each secret
#
# Usage:
#   1. Add your SSH public key(s) to the appropriate list below
#   2. Define secrets with their authorized public keys
#   3. Run `secrets-edit <name>.age` to create/edit encrypted secrets
#   4. Run `secrets-rekey` after changing public keys
#
# To get your SSH public key:
#   cat ~/.ssh/id_ed25519.pub
#
let
  # User SSH public keys
  coopermaruyama = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA+M/DHDlKgayM6wsiX6r704pE+2qENOsKcytC7sBhKA";

  # CI/CD keys
  # Generate with: ssh-keygen -t ed25519 -C "github-actions" -f github-actions-key
  # Add the private key to GitHub Secrets as AGENIX_SSH_KEY
  # Then paste the public key here:
  # github-actions = "ssh-ed25519 AAAA...";

  # Group all users who should have access to secrets
  allUsers = [
    coopermaruyama
    # github-actions  # Uncomment after adding the CI key
  ];
  # Host keys (optional - for server deployments)
  # production = "ssh-ed25519 AAAA...";
  # allHosts = [ production ];
in {
  # Define your secrets here. Example:
  "openai-api-key.age".publicKeys = allUsers;
  # "database-url.age".publicKeys = allUsers;
  # "aws-credentials.age".publicKeys = allUsers;
}

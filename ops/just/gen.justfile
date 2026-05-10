# Generate recipients by scanning Github and pulling public keys for

# all team members
recipients:
    #!/usr/bin/env bash
    usernames="$(gh api /orgs/darkmatter/members --jq '.[].login')"
    for username in $usernames; do
      echo "$username: $(gh api /users/$username/keys --jq '.[].key')" \
        | tee -a recipients.nix
    done

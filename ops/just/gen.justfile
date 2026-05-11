# Generate age recipients for org members into keys/generated/recipients.json
#
# Fetches SSH public keys from GitHub for every member of the darkmatter org,
# converts ed25519 keys to age recipients via ssh-to-age, and writes a single
# JSON object keyed by username.  sops.nix imports this to build .sops.yaml.
#
# Usage:
#   just gen recipients

# Generate age recipients for github org team members
recipients:
    #!/usr/bin/env bash
    set -euo pipefail

    outdir="{{ justfile_directory() }}/keys/generated"
    outfile="$outdir/recipients.json"
    tmpfile="$outfile.tmp"

    mkdir -p "$outdir"
    rm -f "$outdir"/*.nix

    usernames="$(gh api /orgs/darkmatter/members --jq '.[].login')"

    echo "{" > "$tmpfile"
    first_user=1

    for username in $usernames; do
      keys="$(gh api "/users/$username/keys" --jq '.[].key' 2>/dev/null || true)"

      # Convert ed25519 SSH keys to age recipients.
      age_keys=()
      if [ -n "$keys" ]; then
        while IFS= read -r ssh_key; do
          case "$ssh_key" in
            ssh-ed25519*)
              age_key="$(echo "$ssh_key" | nix run nixpkgs#ssh-to-age 2>/dev/null || true)"
              if [ -n "$age_key" ]; then
                age_keys+=("$age_key")
              fi
              ;;
          esac
        done <<< "$keys"
      fi

      if [ "$first_user" -eq 0 ]; then
        echo "," >> "$tmpfile"
      fi
      first_user=0

      printf '  "%s": [' "$username" >> "$tmpfile"
      if [ ${#age_keys[@]} -gt 0 ]; then
        echo "" >> "$tmpfile"
        for index in "${!age_keys[@]}"; do
          key="${age_keys[$index]}"
          if [ "$index" -gt 0 ]; then
            echo "," >> "$tmpfile"
          fi
          printf '    "%s"' "$key" >> "$tmpfile"
        done
        echo "" >> "$tmpfile"
        printf '  ]' >> "$tmpfile"
      else
        printf ']' >> "$tmpfile"
      fi

      echo "  $username: ${#age_keys[@]} age key(s)"
    done

    echo "" >> "$tmpfile"
    echo "}" >> "$tmpfile"
    mv "$tmpfile" "$outfile"

    echo ""
    echo "Wrote $outfile"
    echo "Done. Run \`just rekey\` to regenerate .sops.yaml"

default:
    just --list

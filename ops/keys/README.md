# Self-Service Key Management

To decrypt secrets, add your key to the `team` directory, commit, then push.
CI will re-encrypt using your key, and then you can pull and decrypt the secrets.

## Adding your key

Use the self-service join utility:

```bash
nix run github:darkmatter/tools#sops-join
```

The utility will:

1. Find or clone your local `darkmatter/tools` checkout.
2. Generate a personal age identity and append it to the standard SOPS age key file.
3. Write the public recipient to `ops/keys/team/<username>.pub`.
4. Regenerate `.sops.yaml` from `sops.nix`.
5. Optionally commit and push the recipient change.

Pushing the commit triggers the SOPS rekey workflow. CI uses the repository `SOPS_AGE_KEY` secret to decrypt the current files, runs `sops updatekeys`, and commits the rekeyed files back. After CI finishes:

```bash
git pull
sops decrypt ops/secrets/rclone-config.sops.yaml >/dev/null && echo "Decrypted successfully"
```

If you are on the Darkmatter Tailscale network, the keyservice may already let you decrypt without a personal recipient. Add your own recipient anyway so access is explicit, auditable, and does not depend on the keyservice being reachable. Use separate recipients for service/agent identities instead of reusing a human key.

Manual equivalent:

```bash
git clone git@github.com:darkmatter/tools
cd tools
age-keygen >> ~/Library/Application\ Support/sops/age/keys.txt
echo "age1..." > ops/keys/team/<username>.pub
nix eval --raw -f ./sops.nix yaml > .sops.yaml
git add ops/keys/team/<username>.pub .sops.yaml
git commit -m "chore(secrets): add sops recipient for <username>"
git push
```

## Generating keys from GitHub

To automatically fetch age keys for every org member from their GitHub SSH keys:

```bash
just gen recipients
```

This writes `ops/keys/generated/recipients.json`, keyed by GitHub username. It is
imported by `sops.nix` when building `.sops.yaml`.

## Regenerating `.sops.yaml`

After changing any keys (in `ops/keys/default.nix`, `ops/keys/generated/recipients.json`, or `ops/keys/team/`):

```bash
just rekey
```

Then update the encrypted secrets to use the new recipients:

```bash
sops updatekeys ops/secrets/rclone-config.sops.yaml
```

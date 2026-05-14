# Self-Service Key Management

To decrypt secrets, add your key to the `team` directory, commit, then push.
CI will re-encrypt using your key, and then you can pull and decrypt the secrets.

## Adding your key

```bash
# clone the repository
git clone git@github.com:darkmatter/tools
cd tools

# (Optional) Generate a key: It's important to use this exact path,
# otherwise sops won't automatically detect your key.
age-keygen >> ~/Library/Application\ Support/sops/age/keys.txt
Public key:  age123....

# Put your public key in the team directory. Use your git username as the filename.
echo "age123...." > keys/team/<username>.pub

# Commit and push to update the encrypted secrets.
git add keys/team/<username>.pub
git commit -m "Add <username> key"
git push

# Wait for CI to re-encrypt the secrets, then pull and decrypt.
git pull
sops decrypt ops/secrets/rclone-config.sops.yaml && echo "Decrypted successfully"
```

## Generating keys from GitHub

To automatically fetch age keys for every org member from their GitHub SSH keys:

```bash
just gen recipients
```

This writes `keys/generated/recipients.json`, keyed by GitHub username. It is
imported by `sops.nix` when building `.sops.yaml`.

## Regenerating `.sops.yaml`

After changing any keys (in `keys/default.nix`, `keys/generated/recipients.json`, or `keys/team/`):

```bash
just rekey
```

Then update the encrypted secrets to use the new recipients:

```bash
sops updatekeys ops/secrets/rclone-config.sops.yaml
```

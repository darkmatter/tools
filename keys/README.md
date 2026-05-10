# Self-Service Key Management

To decrypt secrets, add your key to the "team" directory, commit, then push. 
CI will re-encrypt using your key, and then you can pull and decrypt the secrets.

## Guide for adding your key:

```bash
# clone the repository
$ git clone git@github.com:darkmatter/nix
$ cd path/to/nix

# (Optional) Generate a key: It's important to use this exact path,
# otherwise sops won't automatically detect your key.
$ age-keygen >> ~/Library/Application\ Support/sops/age/keys.txt
Public key:  age123....

# Put your public key in the team directory. Use your git username as the filename.
$ echo "age123...." > team/<username>.pub

# Commit and push to update the encrypted secrets.
$ git add team/<username>.pub
$ git commit -m "Add <username> key"
$ git push

# Wait for CI to re-encrypt the secrets, then pull and decrypt.
$ git pull
$ sops decrypt ops/secrets/rclone-config.sops.yaml && echo "Decrypted successfully"

# Now you can use the decrypted secrets.
```

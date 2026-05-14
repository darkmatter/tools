# Darkmatter Nix Devkit

This repo contains several utilities for the Darkmatter team - the goal being that all tools required to onboard and be productive can be encapsulated in a single Nix flake. 

## Quick Start

To launch the main command menu, simply run:

```bash
nix run github:darkmatter/tools
```

The following is a list of the goals of this flake and its current status:

## 1. Shared Secrets + Self-Serve Rekeys

> Status: **Ready** ✅

The secrets required to get set up are checked into this repo age-encrypted using SOPS. The only issue with SOPS is that it requires someone with the ability to decrypt the secrets to rekey in order to onboard new team members.

**Accessing Secrets**

In the `keys` directory, you can add your own age public key and then commit it back into this repo:

```bash

# 1a) Generate an age key from your existing SSH key
$ nix run nixpkgs#ssh-to-age -- \
  -i ~/.ssh/id_ed25519.pub \
  >> ~/Library/Application\ Support/sops/age/keys.txt # put it here to have SOPS autodetect it

# 1b) Alternatively, generate a key from scratch
$ nix develop nixpkgs#age -c age-keygen >> ~/Library/Application\ Support/sops/age/keys.txt

# Add your key to the repo
echo "age.." > ops/keys/team/<username>.pub

git add ops/keys/team/<username>.pub
git commit -m "Add my age public key"

# Push the changes to the repo
git push
```

That will kick off a GitHub Actions workflow that will rekey the secrets using your key. Since the action has it's own key, it does not require human intervention, and piggybacks on our Github roles which are provisioned by our internal SSO (Authentik) which is convenient.

After you pull, you'll find you can decrypt the secrets using your key.

```bash
sops decrypt secrets/<secret>.yaml
```

## 2. Shared Drive

> Status: **Ready** ✅

The `rclone setup` command will mount our shared Google Drive at `~/darkmatter/shared`, and mount a personal drive for you at `~/darkmatter/<username>`. The OAuth secrets are checked into this repo age-encrypted to simplify onboarding. The setup tool will have you log into your Google account in a browser to grant access.


via `fuse3` and `rclone`, as well as a command menu for managing the shared Drive and other utilities.

## 3. LLMs / Agent Utilities

> TODO

## Other Tools Included

This flake exposes runnable utilities for the team.

### `rclone-drive-setup`

Recommended first-time setup for Google Drive mounts:

`nix run github:darkmatter/tools#rclone-drive-setup`

The interactive `gum` wizard walks teammates through:

- decrypting the shared Google Drive config with the shared `SOPS_KEYSERVICE`
- detecting whether host FUSE support is available
- offering to install FUSE where possible, including macFUSE via Homebrew on macOS and `fuse3` via common Linux package managers
- choosing the shared Drive mount path, defaulting to `~/darkmatter/shared`
- optionally configuring an additional personal Google Drive remote with `rclone config`
- choosing the personal Drive mount path, defaulting to `~/darkmatter/<username>`
- mounting the shared and optional personal drives

The shared Drive uses the encrypted team remote `darkmatter-google-drive`. The personal Drive uses a local rclone remote named `darkmatter-personal` in `~/.config/rclone/rclone.conf`.

Mounted volume names are set from the chosen mount directory basename. For example, a shared mount at `~/darkmatter/shared` should appear as `shared` instead of `darkmatter-google-drive`.

### `rclone-drive`

Mount a Google Drive remote directly with `rclone`:

`nix run github:darkmatter/tools#rclone-drive -- ~/path/to/dir`

Arguments:

- argument 1: local mount directory
- optional argument 2: `rclone` remote or remote path, defaulting to `darkmatter-google-drive`

Examples:

`nix run github:darkmatter/tools#rclone-drive -- ~/Drive`

`nix run github:darkmatter/tools#rclone-drive -- ~/Drive darkmatter-google-drive:Shared`

The direct mount runs in the foreground. When you are done, stop the command with `Ctrl-C`; if needed, unmount manually with the usual command for your OS, such as `umount ~/path/to/dir` on macOS or `fusermount3 -u ~/path/to/dir` on Linux.

### Shared Google Drive config

Google Drive is supported by `rclone`, including `rclone mount`. Unlike S3 profile-based auth, Google Drive usually needs an OAuth-backed `rclone` remote configuration. This repo checks in the team config encrypted with SOPS.

By default, the wrappers decrypt `ops/secrets/rclone-config.sops.yaml` at runtime with:

`sops --decrypt --extract '["contents"]'`

They write the decrypted config to a private runtime `rclone.conf`, export `RCLONE_CONFIG` to that generated file, and then start `rclone mount`.

The wrappers also default:

`SOPS_KEYSERVICE=tcp://sops-keyservice.tail6277a6.ts.net:5000`

You can override either `SOPS_KEYSERVICE` or `RCLONE_CONFIG` in the environment if needed. If `RCLONE_CONFIG` is already set, the wrappers use that file instead of decrypting the checked-in SOPS config.

To update the encrypted shared Google Drive config:

1. Copy `ops/secrets/rclone-google-drive.conf.example` to a temporary local file outside git.
2. Run `rclone config` and create or update a Google Drive remote named `darkmatter-google-drive`.
3. Copy the generated `[darkmatter-google-drive]` block into your temporary file.
4. Encrypt that file into the top-level `contents` key in `ops/secrets/rclone-config.sops.yaml`:

`sops set ops/secrets/rclone-config.sops.yaml '["contents"]' "$(jq -Rs . < /path/to/filled-rclone.conf)"`

The checked-in `ops/secrets/rclone-config.sops.yaml` file should contain the encrypted `rclone.conf` content under `contents` only. Do not commit the temporary plaintext config.

### FUSE requirements

`rclone mount` requires host FUSE support.

On macOS, the wizard can install macFUSE with Homebrew:

`brew install --cask macfuse`

macOS may still require approving macFUSE in System Settings and rebooting before mounts work.

On Linux, ensure FUSE is installed and available for your user. The wizard can install `fuse3` with common package managers where available.

## Shared Agent Skills

Team-wide agent skills live in `github:darkmatter/agents` and are re-exported here so consumers only need one Darkmatter flake input:

```nix
{
  inputs.darkmatter.url = "github:darkmatter/tools";

  imports = [
    inputs.darkmatter.homeManagerModules.default
  ];
}
```

The default Home Manager module installs all shared `darkmatter/*` skills for Claude, Codex, and `$HOME/.agents/skills`.

Personal skills can stay outside git and be layered in locally:

```nix
{
  darkmatter.agentSkills.personalPath = /Users/me/.config/darkmatter/skills;
}
```

Personal skills are installed with the `personal/*` prefix.

### Layer registry skills into Claude, Codex, OpenCode, Cursor, and Zed

The default module can be combined with any `agent-skills-nix` catalog. Add the catalog as a flake input, pass `inputs` to Home Manager, then add a source and enable the targets you want.

For a registry entry named `anthropic-skills`:

```nix
{
  inputs = {
    darkmatter.url = "github:darkmatter/tools";
    anthropic-skills.url = "flake:anthropic-skills";

    home-manager.url = "github:nix-community/home-manager";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ home-manager, nixpkgs, darkmatter, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;

      extraSpecialArgs = {
        inherit inputs;
      };

      modules = [
        darkmatter.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
```

Then configure the additional catalog in `home.nix`:

```nix
{ ... }:

{
  programs.agent-skills = {
    sources.anthropic = {
      input = "anthropic-skills";
      subdir = "skills";
      idPrefix = "anthropic";
    };

    skills.enable = [
      "anthropic/frontend-design"
      "anthropic/skill-creator"
    ];

    targets.claude.enable = true;
    targets.codex.enable = true;
    targets.opencode.enable = true;
    targets.cursor.enable = true;

    # `agent-skills-nix` does not currently define a built-in Zed target,
    # but custom targets work the same way.
    targets.zed = {
      enable = true;
      dest = "$HOME/.config/zed/skills";
      structure = "symlink-tree";
    };
  };
}
```

This installs Darkmatter preset skills under `darkmatter/*` plus the selected registry skills under `anthropic/*` into Claude, Codex, OpenCode, Cursor, and Zed.

## Shared Secrets

NixOS hosts can import shared encrypted secrets with:

```nix
{
  imports = [ inputs.darkmatter.nixosModules.secrets ];
}
```

nix-darwin hosts can import the same definitions with:

```nix
{
  imports = [ inputs.darkmatter.darwinModules.secrets ];
}
```

By default all shared Darkmatter secrets are installed. Limit the set with:

```nix
{
  darkmatter.secrets.names = [ "openai-api-key" ];
}
```

## Shared Flake Utilities

This flake also exposes a few runnable utilities for the team.

### Cloudflare R2 mounts at `~/darkmatter`

Three Cloudflare R2 buckets are exposed as local FUSE mounts under `~/darkmatter`:

- `~/darkmatter/public`  &mdash; bucket `darkmatter-public`
- `~/darkmatter/team`    &mdash; bucket `darkmatter-team`
- `~/darkmatter/personal` &mdash; bucket `darkmatter-personal`

One-time setup &mdash; create the rclone remote (`darkmatter-r2`):

```bash
# Will prompt for account id / access key / secret if not in env.
R2_ACCOUNT_ID=... R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=... \
  nix run github:darkmatter/tools#configure-darkmatter-r2
```

Mount everything (or a single bucket):

```bash
nix run github:darkmatter/tools#mount-darkmatter
nix run github:darkmatter/tools#mount-darkmatter -- team
```

Unmount:

```bash
nix run github:darkmatter/tools#unmount-darkmatter
nix run github:darkmatter/tools#unmount-darkmatter -- personal
```

Override the mount root for a single invocation with `DARKMATTER_BASE_DIR=/some/path`.

To customize bucket names, the rclone remote name, or the mount layout in another flake, import the module and override the options:

```nix
{
  imports = [ inputs.darkmatter.flakeModules.r2 ];

  perSystem = { ... }: {
    darkmatter.r2 = {
      enable = true;
      accountId = "<cloudflare-account-id>";
      mounts.team.bucket = "my-team-bucket";
      mounts.archive = { bucket = "my-archive-bucket"; };
    };
  };
}
```

## Quick Start

**Run all the apps at once**

```bash
> devenv up
```

**Enter the full development environment**

```bash
# This will take a while to load the first time or after updates are made to it
> devenv shell --profile all
```

**View all details of the devenv**

```bash
> cd path/to/root
> devenv show
```

This will show you every aspect of the dev environments including scripts, tasks, environment variables, etc

## Profiles

There are several profiles which will provide different environments which are compatible with different apps. For example:

- **`devenv shell --profile proto`**: Includes python, go, and typescript with the versions needed by `buf`
- **`devenv shell --profile minimal`**: Loads a stripped down env that excludes large dependencies such as tensorstore, postgres, etc. Expect not all things to work with this profile
- **`devenv shell --profile ci`**: Used by Github Actions
- devenv shell --profile all\`: Enables everything at once, creates multiple venvs

## Running Tasks

```bash
# Run all the code generation plugins on the protocol buffers
> devenv tasks run proto:generate

# Run the apollo web server
> devenv processes up apollo-server

# Run one-off commands in the development environment
> devenv shell -- db-migrate
```

## Scripts v.s. Tasks v.s. Processes

There are 3 types of excutables that can be defined in devenv which can get quite confusing:

**scripts:**
Available as binary executables in the dev shell. The unique thing about scripts is that they can declare their own packages which means they are ideal for situations where you need flexibility on dependencies. For example, let's say we want to `apps/nn` using Metal on OSX - this requires an older version of jax since jax-ml is behind, which also means we need an older python. Here's how you can do that:

```nix

scripts.nn-osx = with pkgs.python310Packages; {
  description = "Run NN with support for Metal on OS X";
  exec = ''
    ${pkgs.uv}/bin/uv run \
      --python ${pkgs.python310}/bin/python \
      --with jax-ml jax
  '';
  packages = [pkgs.uv pkgs.python310 pkgs.python310Packages.jax-ml pkgs.python310Packages.jax];
};

```

You can even create scripts in any language:

```nix

scripts.go-util = {
  description = "Running some golang code";
  exec = ''
    print("Hello World")
  '';
  package = pkgs.python311;
};
```

**Tasks:**

Tasks are similar to steps in Github Actions, and differ from scripts in the following ways:

- Cannot declare arbitrary packages, but you can call scripts in tasks which means you can just combinefd them if neededl
- Can declare dependencies, e.g. `go build` must run before `go run .`
- Can receive inputs and pass outputs to other tasks
- You can configure the `status` attribute which will let you skip the task conditionally. This is used for example to skip `go mod tidy` in the case where you already have the correct dependenciees installed.

```nix
tasks."go:install"
tasks."go:build"
```

**Processes:**

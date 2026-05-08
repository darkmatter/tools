# Nix Tooling

This directory contains all the nix modules that are used in this repo. We use [devenv](https://devenv.sh) which is a friendlier method to use Nix for non-Nix users, while still being powerful.

## Shared Agent Skills

Team-wide agent skills live in `github:darkmatter/agents` and are re-exported here so consumers only need one Darkmatter flake input:

```nix
{
  inputs.darkmatter.url = "github:darkmatter/nix";

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
    darkmatter.url = "github:darkmatter/nix";
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
  nix run github:darkmatter/nix#configure-darkmatter-r2
```

Mount everything (or a single bucket):

```bash
nix run github:darkmatter/nix#mount-darkmatter
nix run github:darkmatter/nix#mount-darkmatter -- team
```

Unmount:

```bash
nix run github:darkmatter/nix#unmount-darkmatter
nix run github:darkmatter/nix#unmount-darkmatter -- personal
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

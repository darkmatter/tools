{
  description = "Darkmatter devshell - reusable Nix modules for development environments";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    darkmatter-agents.url = "github:darkmatter/agents";
    darkmatter-agents.inputs.agent-skills.inputs.nixpkgs.follows = "nixpkgs";
    darkmatter-agents.inputs.agent-skills.inputs.home-manager.follows = "home-manager";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      agenix,
      darkmatter-agents,
      flake-parts,
      self,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      imports = [
        inputs.flake-parts.flakeModules.modules
        ./flake/apps.nix
        ./flake/packages.nix
        ./flake/devshells.nix
        ./flake/modules/flake-parts/default.nix
      ];

      flake = {
        # Flake-parts modules - for use in any flake-parts based flake
        # Usage: imports = [ inputs.darkmatter.flakeModules.default ];
        flakeModules = {
          default = ./flake/modules/flake-parts/default.nix;
          agenix-rekey = ./flake/modules/flake-parts/agenix-rekey.nix;
          r2 = ./flake/modules/flake-parts/r2.nix;
        };
        homeManagerModules = {
          default = import ./flake/modules/home-manager/default.nix { inherit darkmatter-agents; };
          agents = import ./flake/modules/home-manager/agents.nix { inherit darkmatter-agents; };
        };
        nixosModules = {
          default = import ./flake/modules/nixos/default.nix { inherit agenix; };
          secrets = import ./flake/modules/nixos/default.nix { inherit agenix; };
        };
        darwinModules = {
          default = import ./flake/modules/darwin/default.nix { inherit agenix; };
          secrets = import ./flake/modules/darwin/default.nix { inherit agenix; };
        };
      };

      perSystem = {
        # Enable agenix-rekey workflow generation for this repo
        darkmatter.ci.agenix-rekey = {
          enable = true;
          cachix.enable = true;
          cachix.name = "darkmatter";
        };
        # Expose mount-darkmatter / unmount-darkmatter / configure-darkmatter-r2
        # apps that mount Cloudflare R2 buckets at ~/darkmatter/{public,team,personal}.
        darkmatter.r2.enable = true;
      };
    };
}

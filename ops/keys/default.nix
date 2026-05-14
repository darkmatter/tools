# Central source of truth for all SSH and age keys.
#
# Consumers:
#   sops.nix                                  -- .sops.yaml generation
#
# To regenerate .sops.yaml after changing keys here:
#   just rekey
{
  # Operator SSH keys
  # All operators receive access to every host that imports
  # modules/shared/authorized-keys.nix.
  operators = {
    # Cooper -- primary operator (cm@nixmac)
    cooper = {
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA+M/DHDlKgayM6wsiX6r704pE+2qENOsKcytC7sBhKA cm@nixmac"
      ];
    };

    # drkmttr-admin -- shared deployment identity
    drkmttr-admin = {
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ1T5D9zqaNlrpRG0K1zWOcCupSJaXR60sj4v5eO7j4r drkmttr-admin"
      ];
    };

    # drkmttr-hetzner -- Hetzner deployment identity
    drkmttr-hetzner = {
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII6sIqKDj179VNK6IkC3/thToWY6d0hYFdeOTwkk4o++ drkmttr-hetzner"
      ];
    };

    # hz-hel-deploy -- per-host deploy key for hz-hel-1 (admin + root + VMs)
    hz-hel-deploy = {
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINh0gA7reCRW+zQ5pPpIjoJGpaFQSbC/4K8B6vMXJVr+ hz-hel-deploy"
      ];
    };
  };

  # Operator age keys (SOPS encryption recipients).
  # Every creation_rule in sops.nix includes all of these.
  adminAgeKeys = [
    "age1ua3n0xa25z5tnrhhkndmkpz9elwsxw5jzq89fwldwlcm6wxg9ddsaxksm4"
    "age1unp2wxu3h5t5up5zsnqurwac69v84vtuy8lllpdwf03gddc6xfws00nu2a"
    "age164al9lamrv4ufza9wvg5g5kh863yenq0gdggyxujugxqlv00894spd6jj9"
    "age1vapyvpjzqg8wdfay055s574qt0u6avtzv4ch7kv0epvtycpyjqzqk3m4yr"
  ];

  # Host age keys -- SSH ed25519 host keys converted to age recipients.
  # Derived via: echo "<ssh-ed25519 key>" | nix run nixpkgs#ssh-to-age
  hostAgeKeys = {
    # apollo-staging (5.223.81.29) -- ssh-ed25519 AAAAC3...kzYx
    apollo-staging = "age1v37wpvtxpr2vhvlqpvvzn3h893p8p6pdwfdzvwlr2627u4aj9c7qc0sj5h";

    # titan-prod (15.204.104.4) -- ssh-ed25519 AAAAC3...mnY
    titan-prod = "age1fl49zw0clyxawnp4k4e7t2z6sznn4p9cpvsmw5v9pztlr4egzgjsa28wre";

    # hz-hel-1 (65.108.233.35) -- ssh-ed25519 AAAAC3...10g
    hz-hel-1 = "age13mn4c0kc5q0k4p938hfm433ryy9fp7dywt73g8v3n36q9g5ntszquv67nr";

    # runner-hz-hel-slate sops-keyservice (catch-all recipient)
    key-service = "age16wuzuxnkcgfuxzvzgk5e5a5f6hhs386adjewyv54m9esr4yj6uuslpn6tp";

    # Shared runner identity (all runner hosts)
    runner = "age1eqcj2g0fdekj2wpqp4y0fg9c5myydjdt9zlr5scr0grk6fxszymqkpw5jf";

    # Production role key (used in broad prod path_regex rule)
    prod = "age1c2q5fm3l3gn2tgcs35xstu44mu2zyrft993ksljw5r3z4dzcqcfq6vtakn";

    # macincloud-1 (reserved)
    macincloud = "age1tk24f3ydhcj5quyeevqgup0y73dygda2vzr298sr34xn0n92ae7q474khy";

    # hz-hel-1 microvm host key (reserved)
    hz-hel-vm1 = "age1l7ekaqz3ywl33t26anu39hpq7c6neajdfd5059v7837umetfrgnsrjsnxk";

    # Legacy alias -- "hetzner-hel" was hz-hel-1 before host was confirmed
    hetzner-hel = "age13mn4c0kc5q0k4p938hfm433ryy9fp7dywt73g8v3n36q9g5ntszquv67nr";
  };

  # Service SSH keys (non-operator identities)
  serviceKeys = {
    # Remote Nix builder on hz-hel-1 (root only)
    nix-daemon-builder = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILVJhs0INZc7bMc+jdOGnAm24i2e4ryCNcw88wT0enn2 nix-daemon-builder";
  };
}

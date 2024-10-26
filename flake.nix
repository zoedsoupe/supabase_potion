{
  description = "Supabase SDK for Elixir";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    flake-parts,
    systems,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;
      perSystem = {
        pkgs,
        system,
        ...
      }: let
        inherit (pkgs.beam.interpreters) erlang_27;
        inherit (pkgs.beam) packagesWith;
        beam = packagesWith erlang_27;
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        devShells.default = with pkgs;
          mkShell {
            name = "supabase-ex";
            packages = with pkgs;
              [beam.elixir_1_17 postgresql]
              ++ lib.optional stdenv.isLinux [inotify-tools]
              ++ lib.optional stdenv.isDarwin [
                darwin.apple_sdk.frameworks.CoreServices
                darwin.apple_sdk.frameworks.CoreFoundation
              ];
          };
      };
    };
}

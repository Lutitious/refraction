{
  description = "Discord bot for Prism Launcher";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = lib.genAttrs systems;
      nixpkgsFor = nixpkgs.legacyPackages;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              redis

              # linters & formatters
              actionlint
              nodePackages.prettier

              # rust tools
              clippy
              rustfmt
              rust-analyzer

              # nix tools
              self.formatter.${system}
              nil
              statix
            ];

            inputsFrom = [ self.packages.${pkgs.system}.refraction ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
        }
      );

      formatter = forAllSystems (system: nixpkgsFor.${system}.nixfmt-rfc-style);

      nixosModules.default = import ./nix/module.nix self;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
          packages' = self.packages.${system};

          mkStatic = pkgs.callPackage ./nix/static.nix {
            inherit (self.packages.${pkgs.system}) refraction;
            rust-overlay = rust-overlay.packages.${system};
          };

          mkContainerFor =
            refraction:
            pkgs.dockerTools.buildLayeredImage {
              name = "refraction";
              tag = "latest-${refraction.stdenv.hostPlatform.qemuArch}";
              config.Cmd = [ (lib.getExe refraction) ];
              inherit (refraction) architecture;
            };
        in
        {
          refraction = pkgs.callPackage ./nix/derivation.nix { inherit self; };

          static-x86_64 = mkStatic { arch = "x86_64"; };
          static-aarch64 = mkStatic { arch = "aarch64"; };
          container-x86_64 = mkContainerFor packages'.static-x86_64;
          container-aarch64 = mkContainerFor packages'.static-aarch64;

          default = packages'.refraction;
        }
      );

      overlays.default = _: prev: {
        refraction = prev.callPackage ./nix/derivation.nix { inherit self; };
      };
    };
}

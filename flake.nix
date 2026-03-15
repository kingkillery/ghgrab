{
  description = "A simple, pretty terminal tool to search and download files from GitHub";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage rec {
          pname = "ghgrab";
          version = "1.0.1";

          src = pkgs.fetchFromGitHub {
            owner = "abhixdd";
            repo = "ghgrab";
            rev = "v${version}";
            sha256 = "sha256-hcQU00DjcnHrlie8qsIvvtsyiyuqD9dSiWu1c0mv6fs=";
          };

          cargoHash = "sha256-SGcbdpcvK9F3q4x+bMwGdLARMg3ResqS8k0ToMfSBAw=";

          nativeBuildInputs = [ pkgs.pkg-config ];

          buildInputs = [
            pkgs.openssl
          ];

          doCheck = false;
        };
      }
    );
}

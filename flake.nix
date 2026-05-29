{
  description = "aeriea - A place to be — embodied modern-life sandbox built around 100% immersion";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        # Rust toolchain available for future gdext / rust-godot interop work
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };
      in
      {
        devShells.default = pkgs.mkShell rec {
          buildInputs = with pkgs; [
            # Godot 4.x — primary engine
            godot_4
            # Rust toolchain (for future gdext / hot-path gdextension work)
            rustToolchain
            # C++ / linking tooling (for gdext and any native extensions)
            clang
            mold
            # JS tooling for docs
            bun
          ];
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH";
        };
      }
    );
}

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
        # Nix-reproducible body asset pipeline (Slice 1 of
        # docs/decisions/body-and-locomotion-slice.md): fetches the PINNED
        # MakeHuman CC0 source and runs the in-repo GDScript converter headless
        # to emit the Godot ArrayMesh + macro blendshapes, with NO manual step.
        #   nix build .#body-assets   →   result/base_body.res
        packages.body-assets = import ./nix/body-assets.nix {
          inherit pkgs;
          godot = pkgs.godot_4;
        };

        # Nix-reproducible modifier registry manifest (Slice B of
        # docs/decisions/body-parameterization.md §6): parses the PINNED MakeHuman
        # CC0 modifier JSON into the data-driven modifier registry via the in-repo
        # GDScript builder, with NO manual step. Separate from body-assets so the
        # body mesh stays byte-stable.
        #   nix build .#modifier-registry   →   result/modifier_registry.json
        packages.modifier-registry = import ./nix/modifier-registry.nix {
          inherit pkgs;
          godot = pkgs.godot_4;
        };

        # Nix-reproducible SPARSE CPU DELTA LIBRARY (Slice C of
        # docs/decisions/body-parameterization.md): from the PINNED MakeHuman source it
        # builds the full ~531-target detail envelope + macro factor-cube as a compact
        # sparse delta artifact (NOT ~531 GPU blendshapes). Separate from body-assets so
        # the base mesh stays byte-stable.
        #   nix build .#body-detail-library   →   result/base_body_detail.{bin,index.json}
        packages.body-detail-library = import ./nix/body-detail-library.nix {
          inherit pkgs;
          godot = pkgs.godot_4;
        };

        # Nix-reproducible PROXY GEOMETRY (eyes/teeth/tongue/genitals): from the PINNED
        # MakeHuman source it imports the eye low-poly proxy + the helper teeth/tongue/
        # genital groups as rigged, morph-following Godot mesh pieces, so the face is
        # complete (eyeballs in sockets, teeth + tongue in the mouth) and the NSFW-first
        # genital piece renders. Separate from body-assets so base_body.res stays byte-stable.
        #   nix build .#body-proxies   →   result/base_body_proxies.{res,index.json} + detail
        packages.body-proxies = import ./nix/body-proxies.nix {
          inherit pkgs;
          godot = pkgs.godot_4;
        };

        # Nix-reproducible Motion-Matching feature DB (Slice 4 of
        # docs/decisions/body-and-locomotion-slice.md): fetches the PINNED
        # 100STYLE BVH archive (CC BY 4.0) and runs the in-repo GDScript ingest
        # tool headless to curate the locomotion subset + build the committed
        # MotionDB resource, with NO manual step.
        #   nix build .#motion-assets   →   result/locomotion_mm.res
        packages.motion-assets = import ./nix/motion-assets.nix {
          inherit pkgs;
          godot = pkgs.godot_4;
        };

        # Canonical test runner — runs every test suite under xvfb, detects
        # truncation (missing RESULTS line = FAIL), and reports aggregate.
        #   nix run .#test
        # DO NOT hand-roll per-suite --quit-after invocations: short budgets
        # truncate before the suite finishes and falsely report low pass counts.
        apps.test =
          let
            # Runtime dependencies needed by tests/run.sh:
            #   - godot_4       → the `godot4` binary
            #   - xvfb-run      → the `xvfb-run` wrapper
            #   - xvfb          → `Xvfb` binary (xvfb-run spawns it)
            #   - bash          → the shell that runs the script
            #   - coreutils     → cd, printf, echo, etc.
            #   - gnugrep       → grep -E / -oP used in run.sh
            testDeps = with pkgs; [ godot_4 xvfb-run xvfb bash coreutils gnugrep ];
            wrapper = pkgs.writeShellApplication {
              name = "aeriea-test";
              # writeShellApplication prepends all runtimeInputs to PATH
              # automatically, so godot4 and xvfb-run are always found whether
              # invoked via `nix run .#test` or any other entry point.
              runtimeInputs = testDeps;
              text = ''
                # `nix run` executes from the caller's cwd; export it as
                # AERIEA_ROOT so the runner can `cd` to the project root rather
                # than using `dirname $0` (which points into the Nix store).
                export AERIEA_ROOT="''${AERIEA_ROOT:-$PWD}"
                exec bash "${self}/tests/run.sh"
              '';
            };
          in
          {
            type = "app";
            program = "${wrapper}/bin/aeriea-test";
          };

        # Launch the interactive TF (transformation) playground scene
        # (tools/tf_play.tscn) in a REAL window on the user's display — NOT
        # headless / NOT xvfb — so the user can drive the TF engine live.
        #   nix run .#tfplay
        # Mirrors apps.test: a writeShellApplication wrapper with godot_4 on
        # PATH. `nix run` executes from the Nix store, so Godot's `--path` must
        # point at the project root; we take it from the caller's cwd via
        # AERIEA_ROOT (same convention as the test runner).
        apps.tfplay =
          let
            wrapper = pkgs.writeShellApplication {
              name = "aeriea-tfplay";
              runtimeInputs = with pkgs; [ godot_4 ];
              text = ''
                export AERIEA_ROOT="''${AERIEA_ROOT:-$PWD}"
                exec godot4 --path "$AERIEA_ROOT" "res://tools/tf_play.tscn" "$@"
              '';
            };
          in
          {
            type = "app";
            program = "${wrapper}/bin/aeriea-tfplay";
          };

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
            # Python 3 (stdlib only) — for standalone R&D probes under
            # experiments/ (e.g. experiments/g-toy, the constrain-then-generate
            # crux feasibility experiment). NOT part of the Godot engine build.
            python3
            # Virtual framebuffer — lets agents run the real WINDOWED game (not
            # --headless) in a CI / headless environment. --headless skips
            # GDScript parsing and misses parse errors; xvfb-run boots a real
            # window under a virtual display so the full script-reload pipeline
            # runs. xvfb-run bundles its own Xvfb path; xorg.xvfb adds Xvfb to
            # PATH for scripts that invoke it directly.
            xvfb-run
            xvfb
          ];
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH";
        };
      }
    );
}

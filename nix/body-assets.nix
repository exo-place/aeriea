# Body asset derivation — nix-reproducible MakeHuman CC0 → Godot ArrayMesh.
#
# Implements docs/decisions/body-and-locomotion-slice.md §1.2: from the PINNED
# MakeHuman source (§1.3) it runs the in-repo GDScript converter headless
# (godot4 --headless; the converter does no rendering, so no X/Vulkan is needed
# in the sandbox) and emits the Godot body asset + manifest. No manual step.
#
# Build:   nix build .#body-assets
# Result:  result/base_body.res, result/base_body.manifest.json
# Regen the committed copy:  see tools/body_converter.gd header / repo regen note.
{ pkgs, godot ? pkgs.godot_4 }:

let
  # §1.3 — the verified pin. CC0 base.obj + .target + default.mhskel live under
  # makehuman/data/ in this tree. (Hash confirmed against nixpkgs' own fetch.)
  makehumanSrc = pkgs.fetchFromGitHub {
    owner = "makehumancommunity";
    repo = "makehuman";
    rev = "v1.3.0";
    hash = "sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "aeriea-body-assets";
  version = "1.3.0-slice1";

  # Only the converter + minimal project shell are needed to run Godot headless.
  src = ../.;

  nativeBuildInputs = [ godot ];

  # The MakeHuman source is passed to the converter via this env var.
  MAKEHUMAN_SRC = makehumanSrc;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    # Godot needs a writable HOME for its config/cache and a writable project
    # tree (it writes .godot/ import metadata). The sandbox /build copy is
    # writable already; just give it a HOME.
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    echo "body-assets: running converter headless against pinned MakeHuman source"
    echo "body-assets: MAKEHUMAN_SRC=$MAKEHUMAN_SRC"

    # --headless: the converter is a pure text->ArrayMesh transform, no render.
    godot4 --headless --path . res://tools/body_converter.tscn --quit-after 600

    test -f assets/body/base_body.res || { echo "body-assets: converter produced no mesh" >&2; exit 1; }
    test -f assets/body/base_body.manifest.json || { echo "body-assets: no manifest" >&2; exit 1; }

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp assets/body/base_body.res "$out/"
    cp assets/body/base_body.manifest.json "$out/"
    runHook postInstall
  '';

  # The output is a deterministic pure function of (pinned source + converter).
  meta = {
    description = "aeriea base body ArrayMesh + macro blendshapes (MakeHuman CC0, Slice 1)";
    license = pkgs.lib.licenses.cc0;
  };
}

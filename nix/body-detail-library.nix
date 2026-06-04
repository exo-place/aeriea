# Sparse CPU delta-library derivation — Slice C of docs/decisions/body-parameterization.md.
# From the PINNED MakeHuman source (the same pin as nix/body-assets.nix §1.3) it runs the
# in-repo GDScript builder headless and emits the compact SPARSE DELTA LIBRARY artifact:
# the full ~531-target detail envelope + the macro factor-cube (caucasian race cube +
# universal muscle/weight cube), each as MOVED render-vertex indices + (dx,dy,dz) deltas.
# NO ~531 GPU blendshapes (which would be ~180 MB; see the build-tool header). NO manual
# step. SEPARATE from body-assets so the base mesh (base_body.res) stays byte-stable.
#
# Build:   nix build .#body-detail-library
# Result:  result/base_body_detail.bin, result/base_body_detail.index.json
#
# Reproducible/byte-stable: the output is a deterministic pure function of (pinned source +
# builder) — records emitted in sorted index order, fixed LE binary layout.
{ pkgs, godot ? pkgs.godot_4 }:

let
  makehumanSrc = pkgs.fetchFromGitHub {
    owner = "makehumancommunity";
    repo = "makehuman";
    rev = "v1.3.0";
    hash = "sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "aeriea-body-detail-library";
  version = "1.3.0-sliceC";

  src = ../.;

  nativeBuildInputs = [ godot ];

  # The MakeHuman source (full 1,280-target tree) is passed via this env var.
  MAKEHUMAN_SRC = makehumanSrc;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    echo "body-detail-library: building sparse CPU delta library from pinned MakeHuman source"
    echo "body-detail-library: MAKEHUMAN_SRC=$MAKEHUMAN_SRC"

    # --headless: the builder is a pure text->binary transform, no render. The budget is a
    # safety ceiling; the tool quits itself once done.
    godot4 --headless --path . res://tools/detail_library_build.tscn --quit-after 2000

    test -f assets/body/base_body_detail.bin || { echo "body-detail-library: builder produced no blob" >&2; exit 1; }
    test -f assets/body/base_body_detail.index.json || { echo "body-detail-library: no index" >&2; exit 1; }

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp assets/body/base_body_detail.bin "$out/"
    cp assets/body/base_body_detail.index.json "$out/"
    runHook postInstall
  '';

  meta = {
    description = "aeriea sparse CPU delta library: full MakeHuman detail targets + macro factor-cube (CC0, Slice C)";
    license = pkgs.lib.licenses.cc0;
  };
}

# Body PROXY-geometry derivation — eyes / teeth / tongue / genitals as rigged,
# morph-following Godot mesh pieces. From the PINNED MakeHuman source (the same pin as
# nix/body-assets.nix) it runs the in-repo GDScript builder (tools/body_proxy_build.gd)
# headless and emits:
#   - base_body_proxies.res            (ArrayMesh, one surface per piece, skinned)
#   - base_body_proxies.index.json     (surface -> piece/material + global vertex slice)
#   - base_body_proxies_detail.{bin,index.json}  (per-proxy sparse morph delta library)
#   - eye_brown.png                    (CC0 eye iris texture copied next to the artifacts)
# No manual step. SEPARATE from body-assets so the base mesh (base_body.res) stays
# byte-stable (the proxies are their OWN assets, not baked into base_body.res).
#
# Build:   nix build .#body-proxies
#
# Reproducible/byte-stable: a deterministic pure function of (pinned source + builder) —
# verts in OBJ order, fixed quad diagonal + reversed winding, deltas in ascending global
# render-vertex index.
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
  pname = "aeriea-body-proxies";
  version = "1.3.0-proxies";

  src = ../.;

  nativeBuildInputs = [ godot ];

  MAKEHUMAN_SRC = makehumanSrc;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    echo "body-proxies: building eye/teeth/tongue/genital proxy geometry from pinned MakeHuman source"
    echo "body-proxies: MAKEHUMAN_SRC=$MAKEHUMAN_SRC"

    # --headless: the builder is a pure text->mesh/binary transform, no render.
    godot4 --headless --path . res://tools/body_proxy_build.tscn --quit-after 2000

    test -f assets/body/base_body_proxies.res || { echo "body-proxies: builder produced no mesh" >&2; exit 1; }
    test -f assets/body/base_body_proxies.index.json || { echo "body-proxies: no surface index" >&2; exit 1; }
    test -f assets/body/base_body_proxies_detail.bin || { echo "body-proxies: no delta blob" >&2; exit 1; }
    test -f assets/body/base_body_proxies_detail.index.json || { echo "body-proxies: no delta index" >&2; exit 1; }

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp assets/body/base_body_proxies.res "$out/"
    cp assets/body/base_body_proxies.index.json "$out/"
    cp assets/body/base_body_proxies_detail.bin "$out/"
    cp assets/body/base_body_proxies_detail.index.json "$out/"
    test -f assets/body/eye_brown.png && cp assets/body/eye_brown.png "$out/" || true
    runHook postInstall
  '';

  meta = {
    description = "aeriea eye/teeth/tongue/genital proxy geometry (rigged, morph-following; MakeHuman CC0)";
    license = pkgs.lib.licenses.cc0;
  };
}

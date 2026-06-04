# Modifier-registry manifest derivation — nix-reproducible MakeHuman CC0 modifier JSON
# -> the data-driven modifier registry (Slice B of docs/decisions/body-parameterization.md
# §6). From the PINNED MakeHuman source (the same pin as nix/body-assets.nix §1.3) it runs
# the in-repo GDScript registry builder headless and emits the deterministic registry
# manifest. No manual step.
#
# This is SEPARATE from nix/body-assets.nix on purpose: it builds ONLY the registry
# manifest, so the body mesh asset (base_body.res) is never touched by Slice B and stays
# byte-stable.
#
# Build:   nix build .#modifier-registry
# Result:  result/modifier_registry.json
{ pkgs, godot ? pkgs.godot_4 }:

let
  # The verified pin (identical to nix/body-assets.nix). The modifier JSON lives under
  # makehuman/data/modifiers/ in this tree.
  makehumanSrc = pkgs.fetchFromGitHub {
    owner = "makehumancommunity";
    repo = "makehuman";
    rev = "v1.3.0";
    hash = "sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "aeriea-modifier-registry";
  version = "1.3.0-sliceB";

  src = ../.;

  nativeBuildInputs = [ godot ];

  # The MakeHuman source is passed to the registry builder via this env var (same hook
  # the body converter uses).
  MAKEHUMAN_SRC = makehumanSrc;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    echo "modifier-registry: parsing pinned MakeHuman modifier JSON -> registry manifest"
    echo "modifier-registry: MAKEHUMAN_SRC=$MAKEHUMAN_SRC"

    # --headless: the builder is a pure text->JSON transform, no render.
    godot4 --headless --path . res://tools/modifier_registry_build.tscn --quit-after 600

    test -f assets/body/modifier_registry.json || { echo "modifier-registry: builder produced no manifest" >&2; exit 1; }

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp assets/body/modifier_registry.json "$out/"
    runHook postInstall
  '';

  # The output is a deterministic pure function of (pinned source + builder).
  meta = {
    description = "aeriea data-driven MakeHuman modifier registry manifest (CC0, Slice B)";
    license = pkgs.lib.licenses.cc0;
  };
}

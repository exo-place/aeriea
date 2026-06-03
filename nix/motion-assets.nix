# Motion-Matching feature-DB derivation — nix-reproducible 100STYLE BVH → Godot
# MotionDB resource (Slice 4 of docs/decisions/body-and-locomotion-slice.md §3.2).
#
# Mirrors nix/body-assets.nix: from the PINNED 100STYLE dataset it runs the
# in-repo GDScript ingest tool headless (godot4 --headless; pure BVH→features
# transform, no render) and emits the committed feature DB. No manual step.
#
# Build:   nix build .#motion-assets
# Result:  result/locomotion_mm.res
# Regen the committed copy:  nix build .#motion-assets && cp result/locomotion_mm.res assets/body/
#
# PINS (Slice-4 motion-dependency RESOLVED — see the decision doc):
#   100STYLE  — Ian Mason, Zenodo record 8127870, CC BY 4.0. 100STYLE.zip
#               (the raw 60fps BVH; 1.47 GB; md5 3cf627852fd8192024c04a8d0ef49583).
#               We fetch the FULL pinned zip and the ingest tool curates the
#               locomotion subset (Neutral/StartStop/March) at build time, so the
#               1.5 GB raw set is NEVER vendored.
#   CMU       — gbionics/cmu-fbx @ d18e9d3d14c08318eaa6c0602a6ead7fac40e58c
#               (license cmu-mocap; "data from mocap.cs.cmu.edu, NSF EIA-0196217").
#               SOURCING RESOLVED + PINNED, but ingest DEFERRED: the mirror ships
#               Kaydara *binary* FBX, which Godot has no runtime parser for. CMU
#               drops in at the same BVH ingest seam once a BVH mirror or an
#               editor-side FBX→BVH step lands (decision doc Slice-4 section).
{ pkgs, godot ? pkgs.godot_4 }:

let
  # §Slice-4 pin — the 100STYLE raw BVH archive (CC BY 4.0).
  # NOTE on the hash: filled from `nix store prefetch-file` of the pinned URL;
  # the md5 (3cf627852fd8192024c04a8d0ef49583) is the Zenodo-published integrity
  # checksum cross-checked against this fetch.
  style100Zip = pkgs.fetchurl {
    url = "https://zenodo.org/api/records/8127870/files/100STYLE.zip/content";
    name = "100STYLE.zip";
    hash = "sha256-LDtAF/jiOX7mkEybn0NVHYtCbTndw1WNEh/unlXLLVg=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "aeriea-motion-assets";
  version = "100style-slice4";

  src = ../.;
  nativeBuildInputs = [ godot ];

  # The ingest tool reads the unpacked 100STYLE dir via STYLE100_SRC. We unzip the
  # pinned archive in the build sandbox (no network).
  STYLE100_ZIP = style100Zip;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    echo "motion-assets: unpacking pinned 100STYLE archive"
    mkdir -p "$TMPDIR/style100"
    ${pkgs.unzip}/bin/unzip -q "$STYLE100_ZIP" -d "$TMPDIR/style100"
    # The ingest tool's locomotion-subset curation expects the BVH under a flat
    # directory; point it at the dataset's 100STYLE/ root so it can walk styles.
    export STYLE100_SRC="$TMPDIR/style100/100STYLE"
    test -d "$STYLE100_SRC" || STYLE100_SRC="$TMPDIR/style100"

    # Flatten the curated subset into the dir the tool lists (it lists one dir of
    # *.bvh): copy only the locomotion-subset styles' clips.
    mkdir -p "$TMPDIR/loco"
    for style in Neutral StartStop March; do
      if [ -d "$STYLE100_SRC/$style" ]; then
        cp "$STYLE100_SRC/$style/"*.bvh "$TMPDIR/loco/" 2>/dev/null || true
      fi
    done
    export STYLE100_SRC="$TMPDIR/loco"
    echo "motion-assets: $(ls "$STYLE100_SRC" | wc -l) locomotion BVH clips"

    # Remove the committed copy from the src tree so a failed/short ingest cannot
    # masquerade as success (the install would otherwise copy the stale committed
    # DB). The build MUST regenerate it.
    rm -f assets/body/locomotion_mm.res

    godot4 --headless --path . res://tools/motion_ingest.tscn --quit-after 6000

    test -s assets/body/locomotion_mm.res || { echo "motion-assets: ingest produced no DB" >&2; exit 1; }

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp assets/body/locomotion_mm.res "$out/"
    runHook postInstall
  '';

  meta = {
    description = "aeriea Motion-Matching feature DB (100STYLE CC BY 4.0, Slice 4)";
    license = pkgs.lib.licenses.cc-by-40;
  };
}

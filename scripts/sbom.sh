#!/usr/bin/env bash
# Generate a CycloneDX SBOM per target and bind it to the exact binary by
# adding the binary's SHA-256 to the SBOM's top-level component.
# Usage: scripts/sbom.sh <rust-target-triple>
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

TARGET="${1:?usage: sbom.sh <target>}"
require_target "$TARGET"
ARCH="${ARCH_OF[$TARGET]}"
OUT="$DIST_DIR/$ARCH"
BIN="$OUT/$BIN_NAME"
[[ -f "$BIN" ]] || die "missing $BIN (run scripts/build.sh $TARGET first)"
command -v cargo-cyclonedx >/dev/null || die "cargo-cyclonedx not installed (cargo install cargo-cyclonedx --locked)"
command -v jq >/dev/null || die "jq not installed"

log "generating CycloneDX SBOM for $TARGET"
cargo cyclonedx --format json --spec-version 1.5 --target "$TARGET" \
  --override-filename "sbom-$ARCH" --quiet
RAW="$REPO_ROOT/sbom-$ARCH.json"
[[ -f "$RAW" ]] || die "cargo-cyclonedx did not produce $RAW"

HASH="$(sha256_of "$BIN")"
RUSTC="$(rustc --version)"
# Enrich: binary hash, target triple, toolchain; drop the random
# serialNumber/timestamp so the SBOM itself is reproducible.
jq --arg h "$HASH" --arg t "$TARGET" --arg r "$RUSTC" \
   --arg ts "$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%M:%SZ)" '
  del(.serialNumber)
  | .metadata.timestamp = $ts
  | .metadata.component.hashes = [{alg: "SHA-256", content: $h}]
  | .metadata.properties = ((.metadata.properties // []) + [
      {name: "build:target", value: $t},
      {name: "build:toolchain", value: $r},
      {name: "build:reproducible", value: "true"}
    ])
' "$RAW" > "$OUT/$BIN_NAME.cdx.json"
rm -f "$RAW"

log "SBOM: $OUT/$BIN_NAME.cdx.json ($(jq '.components | length' "$OUT/$BIN_NAME.cdx.json") components, binary sha256 $HASH)"

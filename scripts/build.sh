#!/usr/bin/env bash
# Cross-compile edgeprobe for one target and stage it in dist/<arch>/.
# Usage: scripts/build.sh <rust-target-triple>
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

TARGET="${1:?usage: build.sh <target>}"
require_target "$TARGET"
ARCH="${ARCH_OF[$TARGET]}"
OUT="$DIST_DIR/$ARCH"

log "building $BIN_NAME for $TARGET (SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH)"
# shellcheck disable=SC2086
cargo build --release --locked --target "$TARGET" $EXTRA_CARGO_FLAGS

mkdir -p "$OUT"
cp "target/$TARGET/release/$BIN_NAME" "$OUT/$BIN_NAME"
( cd "$OUT" && sha256sum "$BIN_NAME" > "$BIN_NAME.sha256" )

log "artifact: $OUT/$BIN_NAME"
log "sha256:   $(cut -d' ' -f1 "$OUT/$BIN_NAME.sha256")"
file "$OUT/$BIN_NAME" 2>/dev/null || true

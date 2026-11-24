#!/usr/bin/env bash
# Fast per-arch smoke test: run the cross-compiled binary under QEMU
# user-mode emulation and check it reports the expected architecture.
# Usage: scripts/qemu-user-smoke.sh <rust-target-triple>
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

TARGET="${1:?usage: qemu-user-smoke.sh <target>}"
require_target "$TARGET"
ARCH="${ARCH_OF[$TARGET]}"
BIN="$DIST_DIR/$ARCH/$BIN_NAME"
[[ -x "$BIN" ]] || die "missing $BIN (run scripts/build.sh $TARGET first)"

RUNNER="${QEMU_USER_OF[$TARGET]:-}"
declare -A EXPECT=([x86_64]=x86_64 [arm64]=aarch64 [armv7]=arm)

log "running $BIN ${RUNNER:+under $RUNNER}"
# shellcheck disable=SC2086
VERSION_JSON="$($RUNNER "$BIN" --version)"
# shellcheck disable=SC2086
HEALTH_JSON="$($RUNNER "$BIN" --health)"
echo "$VERSION_JSON"
echo "$HEALTH_JSON"

grep -q "\"target\":\"$TARGET\"" <<<"$VERSION_JSON" || die "wrong target in --version"
grep -q "\"arch\":\"${EXPECT[$ARCH]}\"" <<<"$HEALTH_JSON" || die "wrong arch in --health"
grep -q '"status":"' <<<"$HEALTH_JSON" || die "no status in --health"
log "OK: $TARGET runs and reports arch=${EXPECT[$ARCH]}"

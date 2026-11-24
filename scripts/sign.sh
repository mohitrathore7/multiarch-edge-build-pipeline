#!/usr/bin/env bash
# Sign the binary and its SBOM with cosign (key-based, no network needed),
# then verify the signatures straight away.
#
# Key material comes from CI variables:
#   COSIGN_PRIVATE_KEY  (file-type variable; path to cosign.key)
#   COSIGN_PASSWORD     (masked)
#   cosign.pub          (committed public key, used for verification)
# Usage: scripts/sign.sh <rust-target-triple>
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

TARGET="${1:?usage: sign.sh <target>}"
require_target "$TARGET"
ARCH="${ARCH_OF[$TARGET]}"
OUT="$DIST_DIR/$ARCH"
KEY="${COSIGN_PRIVATE_KEY:-$REPO_ROOT/cosign.key}"
PUB="${COSIGN_PUBLIC_KEY:-$REPO_ROOT/cosign.pub}"

command -v cosign >/dev/null || die "cosign not installed"
[[ -f "$KEY" ]] || die "signing key not found ($KEY). Set COSIGN_PRIVATE_KEY."
[[ -f "$PUB" ]] || die "public key not found ($PUB)"

for f in "$OUT/$BIN_NAME" "$OUT/$BIN_NAME.cdx.json"; do
  [[ -f "$f" ]] || die "missing $f"
  log "signing $(basename "$f")"
  cosign sign-blob --yes --tlog-upload=false --key "$KEY" \
    --output-signature "$f.sig" "$f" >/dev/null
  cosign verify-blob --insecure-ignore-tlog=true --key "$PUB" \
    --signature "$f.sig" "$f" >/dev/null
  log "verified $(basename "$f").sig"
done

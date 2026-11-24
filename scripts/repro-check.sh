#!/usr/bin/env bash
# Hash-based reproducibility check: build the same commit N times from a
# clean target dir each time and require every binary to be bit-identical.
# Usage: scripts/repro-check.sh <rust-target-triple> [runs=10]
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

TARGET="${1:?usage: repro-check.sh <target> [runs]}"
RUNS="${2:-${REPRO_RUNS:-10}}"
require_target "$TARGET"
ARCH="${ARCH_OF[$TARGET]}"
REPORT="$DIST_DIR/reproducibility-$ARCH.txt"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$DIST_DIR"
log "reproducibility check: $TARGET, $RUNS clean builds"

declare -a HASHES=()
for i in $(seq 1 "$RUNS"); do
  # Vary the build directory on purpose: path leakage would show up as a
  # hash mismatch (guarded against by --remap-path-prefix in .cargo/config.toml).
  TD="$WORK/build-$i"
  # shellcheck disable=SC2086
  CARGO_TARGET_DIR="$TD" cargo build --release --locked --quiet \
    --target "$TARGET" $EXTRA_CARGO_FLAGS
  H="$(sha256_of "$TD/$TARGET/release/$BIN_NAME")"
  HASHES+=("$H")
  printf '  run %2d/%d  %s\n' "$i" "$RUNS" "$H" >&2
  rm -rf "$TD"
done

UNIQUE="$(printf '%s\n' "${HASHES[@]}" | sort -u | wc -l)"
{
  echo "target:            $TARGET"
  echo "source_date_epoch: $SOURCE_DATE_EPOCH"
  echo "commit:            $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "rustc:             $(rustc --version)"
  echo "runs:              $RUNS"
  echo "unique_hashes:     $UNIQUE"
  for i in "${!HASHES[@]}"; do printf 'run_%02d:            %s\n' "$((i + 1))" "${HASHES[$i]}"; done
  if [[ "$UNIQUE" == "1" ]]; then echo "result:            REPRODUCIBLE"; else echo "result:            NOT REPRODUCIBLE"; fi
} | tee "$REPORT"

# Optional: compare against the artifact produced by the build stage.
if [[ -f "$DIST_DIR/$ARCH/$BIN_NAME.sha256" ]]; then
  STAGED="$(cut -d' ' -f1 "$DIST_DIR/$ARCH/$BIN_NAME.sha256")"
  if [[ "$STAGED" != "${HASHES[0]}" ]]; then
    die "build-stage artifact ($STAGED) differs from rebuild (${HASHES[0]})"
  fi
  log "matches build-stage artifact: $STAGED"
fi

[[ "$UNIQUE" == "1" ]] || die "$TARGET is NOT reproducible ($UNIQUE different hashes)"
log "OK: $RUNS/$RUNS builds bit-identical"

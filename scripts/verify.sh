#!/usr/bin/env bash
# Automated build verification: static checks on a cross-compiled artifact
# before anything downstream (SBOM, signing, images) is allowed to use it.
#
#   1. checksum file matches the binary
#   2. ELF class / machine / float ABI match the target
#   3. dynamic loader path matches the target rootfs
#   4. binary is stripped (no .symtab)
#   5. no build-machine paths leaked into the binary
#   6. highest required glibc symbol version <= MAX_GLIBC (target rootfs)
#   7. size budget for constrained devices
#
# Usage: scripts/verify.sh <rust-target-triple>
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

TARGET="${1:?usage: verify.sh <target>}"
require_target "$TARGET"
ARCH="${ARCH_OF[$TARGET]}"
BIN="$DIST_DIR/$ARCH/$BIN_NAME"
MAX_SIZE_KB="${MAX_SIZE_KB:-512}"
MAX_GLIBC="${MAX_GLIBC:-2.34}"

[[ -f "$BIN" ]] || die "missing $BIN (run scripts/build.sh $TARGET first)"

declare -A CLASS=([x86_64]=ELF64 [arm64]=ELF64 [armv7]=ELF32)
declare -A MACHINE=([x86_64]="Advanced Micro Devices X86-64" [arm64]="AArch64" [armv7]="ARM")
declare -A INTERP=(
  [x86_64]=/lib64/ld-linux-x86-64.so.2
  [arm64]=/lib/ld-linux-aarch64.so.1
  [armv7]=/lib/ld-linux-armhf.so.3
)

FAIL=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=1; }
# check "<description>" <command...>: PASS if the command succeeds
check() { local msg="$1"; shift; if "$@"; then pass "$msg"; else fail "$msg"; fi; }
has() { grep -q "$1" <<<"$2"; }

log "verifying $BIN ($TARGET)"

# 1. checksum
if (cd "$DIST_DIR/$ARCH" && sha256sum --quiet -c "$BIN_NAME.sha256"); then
  pass "sha256 matches $BIN_NAME.sha256"
else
  fail "sha256 mismatch"
fi

# 2. ELF header
HDR="$(readelf -h "$BIN")"
check "class ${CLASS[$ARCH]}" has "Class:[[:space:]]*${CLASS[$ARCH]}" "$HDR"
check "machine ${MACHINE[$ARCH]}" has "Machine:[[:space:]]*${MACHINE[$ARCH]}\$" "$HDR"
if [[ "$ARCH" == armv7 ]]; then
  check "armhf (hard-float ABI)" has "hard-float ABI" "$HDR"
fi

# 3. interpreter
GOT_INTERP="$(readelf -l "$BIN" | sed -n 's/.*interpreter: \(.*\)]/\1/p')"
check "interpreter ${INTERP[$ARCH]} (got '$GOT_INTERP')" test "$GOT_INTERP" = "${INTERP[$ARCH]}"

# 4. stripped
check "stripped (no .symtab)" bash -c "! readelf -S '$BIN' | grep -q '\.symtab'"

# 5. path leakage (would break reproducibility across runners)
LEAKS="$(strings "$BIN" | grep -E '^/(root|home|builds|tmp)/' | head -3 || true)"
check "no build paths leaked ${LEAKS:+($LEAKS)}" test -z "$LEAKS"

# 6. glibc floor
NEED="$(objdump -T "$BIN" | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//' | sort -uV | tail -1)"
if [[ "$(printf '%s\n%s\n' "$NEED" "$MAX_GLIBC" | sort -V | tail -1)" == "$MAX_GLIBC" ]]; then
  pass "needs glibc $NEED (<= $MAX_GLIBC)"
else
  fail "needs glibc $NEED (> $MAX_GLIBC, won't run on target rootfs)"
fi

# 7. size
SIZE_KB=$(( $(stat -c%s "$BIN") / 1024 ))
check "size ${SIZE_KB} KiB (budget ${MAX_SIZE_KB} KiB)" test "$SIZE_KB" -le "$MAX_SIZE_KB"

[[ "$FAIL" == 0 ]] || die "verification failed for $TARGET"
log "OK: all checks passed for $TARGET"

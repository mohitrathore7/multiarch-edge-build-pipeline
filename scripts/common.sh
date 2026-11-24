#!/usr/bin/env bash
# Shared helpers for all pipeline scripts.
# Variables here are consumed by the scripts that source this file.
# shellcheck disable=SC2034
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/dist}"
BIN_NAME="edgeprobe"

# Supported targets <-> short arch names used in artifact paths.
declare -A ARCH_OF=(
  [x86_64-unknown-linux-gnu]=x86_64
  [aarch64-unknown-linux-gnu]=arm64
  [armv7-unknown-linux-gnueabihf]=armv7
)
declare -A QEMU_USER_OF=(
  [aarch64-unknown-linux-gnu]="qemu-aarch64 -L /usr/aarch64-linux-gnu"
  [armv7-unknown-linux-gnueabihf]="qemu-arm -L /usr/arm-linux-gnueabihf"
)

# Reproducibility: fixed timestamp = last commit time (or 0 outside git).
if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
  SOURCE_DATE_EPOCH="$(git -C "$REPO_ROOT" log -1 --format=%ct 2>/dev/null || echo 0)"
fi
export SOURCE_DATE_EPOCH
export TZ=UTC LC_ALL=C

# Extra cargo flags hook (e.g. "-Zbuild-std=std,panic_abort" on hosts
# without prebuilt rust-std for a target). Empty in normal CI.
EXTRA_CARGO_FLAGS="${EXTRA_CARGO_FLAGS:-}"

log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(basename "$0")" "$*" >&2; }
die() { printf '\033[1;31m[%s] ERROR:\033[0m %s\n' "$(basename "$0")" "$*" >&2; exit 1; }

require_target() {
  local t="$1"
  [[ -n "${ARCH_OF[$t]:-}" ]] || die "unsupported target '$t' (supported: ${!ARCH_OF[*]})"
}

sha256_of() { sha256sum "$1" | awk '{print $1}'; }

#!/usr/bin/env bash
# Build a minimal embedded Linux image with Buildroot that contains the
# exact, already verified edgeprobe artifact from dist/<arch>/.
#
# Usage: scripts/buildroot-image.sh <rust-target-triple>
# Env:   BUILDROOT_VERSION (default 2024.02.9 LTS), BR_WORK (default .buildroot)
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

TARGET="${1:?usage: buildroot-image.sh <target>}"
require_target "$TARGET"
ARCH="${ARCH_OF[$TARGET]}"
declare -A DEFCONFIG=(
  [x86_64]=qemu_x86_64_defconfig
  [arm64]=qemu_aarch64_virt_defconfig
  [armv7]=qemu_arm_vexpress_defconfig
)

BR_VERSION="${BUILDROOT_VERSION:-2024.02.9}"
BR_WORK="${BR_WORK:-$REPO_ROOT/.buildroot}"
BR_SRC="$BR_WORK/buildroot-$BR_VERSION"
OUT="$BR_WORK/output-$ARCH"
IMAGES_OUT="$REPO_ROOT/br-images/$ARCH"

[[ -x "$DIST_DIR/$ARCH/$BIN_NAME" ]] || die "missing dist/$ARCH/$BIN_NAME (build + verify first)"

mkdir -p "$BR_WORK"
if [[ ! -d "$BR_SRC" ]]; then
  log "fetching Buildroot $BR_VERSION"
  curl -fsSL "https://buildroot.org/downloads/buildroot-$BR_VERSION.tar.xz" | tar -xJ -C "$BR_WORK"
fi

log "configuring ${DEFCONFIG[$ARCH]} + edgeprobe fragment"
make -C "$BR_SRC" O="$OUT" BR2_EXTERNAL="$REPO_ROOT/buildroot" "${DEFCONFIG[$ARCH]}" >/dev/null
"$BR_SRC/support/kconfig/merge_config.sh" -m -O "$OUT" \
  "$OUT/.config" "$REPO_ROOT/buildroot/configs/edgeprobe.fragment" >/dev/null
make -C "$BR_SRC" O="$OUT" olddefconfig >/dev/null

log "building image (this takes a while on a cold cache)"
make -C "$BR_SRC" O="$OUT" -j"$(nproc)"

mkdir -p "$IMAGES_OUT"
cp -a "$OUT/images/." "$IMAGES_OUT/"
log "OK: images in $IMAGES_OUT"
ls -lh "$IMAGES_OUT"

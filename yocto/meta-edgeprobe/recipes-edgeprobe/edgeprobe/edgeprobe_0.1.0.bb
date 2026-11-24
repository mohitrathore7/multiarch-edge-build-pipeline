SUMMARY = "Edge-device health probe (Rust)"
DESCRIPTION = "Reference Rust application for the multi-architecture build pipeline. \
Built from source with the Yocto Rust toolchain for the selected MACHINE."
HOMEPAGE = "https://github.com/mohitrathore7/multiarch-edge-build-pipeline"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=4cc00dc843f0ac87ff03824a6cb59a1e"

# Build the working tree this layer sits in (same commit CI is testing).
inherit externalsrc
EXTERNALSRC = "${EDGEPROBE_SRCDIR}"
EXTERNALSRC_BUILD = "${WORKDIR}/build"

# No crates.io dependencies, so no crate:// SRC_URI entries are needed and
# the build is fully offline.
inherit cargo update-rc.d

# OE-core sets SOURCE_DATE_EPOCH per recipe; build.rs embeds it instead of "now".
export SOURCE_DATE_EPOCH

do_install:append() {
    install -D -m 0755 ${S}/packaging/edgeprobe.init ${D}${sysconfdir}/init.d/edgeprobe
}

INITSCRIPT_NAME = "edgeprobe"
INITSCRIPT_PARAMS = "defaults 99"

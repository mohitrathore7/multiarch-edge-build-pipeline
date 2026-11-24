################################################################################
#
# edgeprobe
#
# No source download: installs the CI artifact from dist/<arch>/ after
# checking it against its recorded SHA-256.
#
################################################################################

# Like Buildroot's skeleton-init-* packages: no VERSION/SOURCE, so the
# download/extract steps are skipped and only the install hooks run.
EDGEPROBE_LICENSE = MIT
EDGEPROBE_REPO = $(BR2_EXTERNAL_EDGEPROBE_PATH)/..

ifeq ($(BR2_x86_64),y)
EDGEPROBE_ARCH = x86_64
else ifeq ($(BR2_aarch64),y)
EDGEPROBE_ARCH = arm64
else ifeq ($(BR2_arm),y)
EDGEPROBE_ARCH = armv7
endif

EDGEPROBE_ARTIFACT_DIR ?= $(EDGEPROBE_REPO)/dist/$(EDGEPROBE_ARCH)

define EDGEPROBE_INSTALL_TARGET_CMDS
	cd $(EDGEPROBE_ARTIFACT_DIR) && sha256sum -c edgeprobe.sha256
	$(INSTALL) -D -m 0755 $(EDGEPROBE_ARTIFACT_DIR)/edgeprobe $(TARGET_DIR)/usr/bin/edgeprobe
endef

define EDGEPROBE_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(EDGEPROBE_REPO)/packaging/edgeprobe.init \
		$(TARGET_DIR)/etc/init.d/S99edgeprobe
endef

$(eval $(generic-package))

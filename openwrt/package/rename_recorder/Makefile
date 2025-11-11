include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

PKG_NAME:=rename_recorder
PKG_RELEASE:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)
SRC_CODE_DIR := ./src/

define Package/$(PKG_NAME)
	SECTION:=rename_recorder
	CATEGORY:=Rename Recorder
	TITLE:=Rename the Recorder MP4 files 1
endef

define Package/$(PKG_NAME)/description
	Rename the Recorder MP4 files 2
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/rename_recorder/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/rename_recorder $(1)/usr/bin/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

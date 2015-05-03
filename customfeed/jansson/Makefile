#
# Copyright (C) 2015 Superglue
#

include $(TOPDIR)/rules.mk

SOURCE_ROOT_DIR:=$(TOPDIR)/..

PKG_NAME:=jansson
PKG_VERSION:=2.2
PKG_RELEASE:=1
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

PKG_INSTALL=1

# Custom variable in order to copy straight from source tree into build tree
PKG_LOCAL_SOURCE_DIR:=$(TOPDIR)/../jansson
PKG_UNPACK:=$(CP) -r $(PKG_LOCAL_SOURCE_DIR)/* $(PKG_BUILD_DIR)

define Package/jansson
	SECTION:=jansson
	CATEGORY:=superglue
	TITLE:=jansson
	MAINTAINER:=Superglue
endef

CONFIGURE_ARGS+= LIBS="-Wl,-rpath-link=$(STAGING_DIR)/usr/lib"

define Package/jansson/description
	jansson - C library for encoding, decoding and manipulating JSON data
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/{lib,include}
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libjansson* $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/include/* $(1)/usr/include/
endef

define Package/jansson/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libjansson*so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,jansson))

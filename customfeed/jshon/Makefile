#
# Copyright (C) 2015 Superglue
#

include $(TOPDIR)/rules.mk

SOURCE_ROOT_DIR:=$(TOPDIR)/..

PKG_NAME:=jshon
PKG_VERSION:=0.1
PKG_RELEASE:=1
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_PARALLEL:=1

PKG_BUILD_DEPENDS:=jansson

include $(INCLUDE_DIR)/package.mk

# Custom variable in order to copy straight from source tree into build tree
PKG_LOCAL_SOURCE_DIR:=$(TOPDIR)/../jshon/
PKG_UNPACK:=$(CP) -r $(PKG_LOCAL_SOURCE_DIR)/* $(PKG_BUILD_DIR)

define Package/jshon
  SECTION:=jshon
  CATEGORY:=Superglue
  TITLE:=jshon
  DEPENDS:=+jansson
  MAINTAINER:=Superglue
endef


define Package/jshon/description
  jshon - parses, reads and creates JSON
endef

define Package/jshon/install
  $(INSTALL_DIR) $(1)/usr/bin/
  $(INSTALL_BIN) $(PKG_BUILD_DIR)/jshon $(1)/usr/bin/
endef

$(eval $(call BuildPackage,jshon,+jansson))

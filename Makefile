include $(TOPDIR)/rules.mk

PKG_NAME:=bakesale
PKG_VERSION:=1
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/bakesale
  CATEGORY:=Extra
  TITLE:=bakesale
  DEPENDS:=+nftables
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/bakesale/conffiles
/etc/config/bakesale
endef

define Package/bakesale/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/bakesale.d
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_DIR) $(1)/usr/lib/sqm

	$(INSTALL_CONF) ./etc/config/bakesale $(1)/etc/config/
	$(INSTALL_CONF) ./etc/bakesale.d/main.nft $(1)/etc/bakesale.d/
	$(INSTALL_CONF) ./etc/bakesale.d/maps.nft $(1)/etc/bakesale.d/
	$(INSTALL_CONF) ./etc/bakesale.d/verdicts.nft $(1)/etc/bakesale.d/
	$(INSTALL_CONF) ./etc/hotplug.d/iface/21-bakesale $(1)/etc/hotplug.d/iface/
	$(INSTALL_BIN) ./etc/init.d/bakesale $(1)/etc/init.d/

	$(INSTALL_DATA) ./usr/lib/sqm/layer_cake_ct.qos $(1)/usr/lib/sqm/
	$(INSTALL_DATA) ./usr/lib/sqm/layer_cake_ct.qos.help $(1)/usr/lib/sqm/
endef

$(eval $(call BuildPackage,bakesale))


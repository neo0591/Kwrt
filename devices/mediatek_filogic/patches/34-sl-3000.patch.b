--- a/target/linux/mediatek/image/filogic.mk
+++ b/target/linux/mediatek/image/filogic.mk
@@ -1672,3 +1672,29 @@ define Device/zyxel_nwa50ax-pro
   IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
 endef
 TARGET_DEVICES += zyxel_nwa50ax-pro
+define Device/philips_hy3000
+  DEVICE_VENDOR := Philips
+  DEVICE_MODEL := HY3000
+  DEVICE_DTS := mt7981b-philips-hy3000
+  DEVICE_DTS_DIR := ../dts
+  DEVICE_PACKAGES := kmod-usb3 f2fsck mkf2fs
+  SUPPORTED_DEVICES += philips,hy3000
+  KERNEL := kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
+  KERNEL_INITRAMFS := kernel-bin | lzma | \
+        fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
+  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
+endef
+TARGET_DEVICES += philips_hy3000
+
+define Device/sl_3000-emmc
+  DEVICE_VENDOR := SL
+  DEVICE_MODEL := 3000 eMMC
+  DEVICE_DTS := mt7981b-sl-3000-emmc
+  DEVICE_DTS_DIR := ../dts
+  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware blkid blockdev fdisk f2fsck mkf2fs kmod-mmc
+  KERNEL := kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
+  KERNEL_INITRAMFS := kernel-bin | lzma | \
+	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
+  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
+endef
+TARGET_DEVICES += sl_3000-emmc

--- a/target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh
+++ b/target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh
@@ -129,6 +129,8 @@ platform_do_upgrade() {
 	glinet,gl-xe3000|\
 	huasifei,wh3000|\
 	huasifei,wh3000-pro|\
+	philips,hy3000|\
+	sl,3000*|\
 	smartrg,sdg-8612|\
 	smartrg,sdg-8614|\
 	smartrg,sdg-8622|\
@@ -350,6 +351,8 @@ platform_copy_config() {
 	huasifei,wh3000-pro|\
 	jdcloud,re-cp-03|\
 	nradio,c8-668gl|\
+	philips,hy3000|\
+	sl,3000*|\
 	smartrg,sdg-8612|\
 	smartrg,sdg-8614|\
 	smartrg,sdg-8622|\

--- a/target/linux/mediatek/filogic/base-files/etc/board.d/02_network
+++ b/target/linux/mediatek/filogic/base-files/etc/board.d/02_network
@@ -41,6 +41,8 @@ mediatek_setup_interfaces()
 	jcg,q30-pro|\
 	keenetic,kn-3811|\
 	qihoo,360t7|\
+	philips,hy3000|\
+	sl,3000*|\
 	routerich,ax3000|\
 	routerich,ax3000-ubootmod)
 		ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" wan
@@ -136,6 +138,16 @@ mediatek_setup_interfaces()
 	tplink,re6000xd)
 		ucidef_set_interface_lan "lan1 lan2 eth1"
 		;;
+	philips,hy3000)
+		lan_mac=$(mmc_get_mac_binary factory 0x74)
+		wan_mac=$(macaddr factory $lan_mac 1)
+		label_mac=$wan_mac
+		;;
+ 	sl,3000-emmc)
+ 		lan_mac=$(mmc_get_mac_binary factory 0x04)		
+ 		wan_mac=$(macaddr_add "$lan_mac" -2)
+ 		label_mac=$lan_mac
+ 		;;
 	xiaomi,mi-router-ax3000t|\
 	xiaomi,mi-router-ax3000t-ubootmod|\
 	xiaomi,mi-router-wr30u|\

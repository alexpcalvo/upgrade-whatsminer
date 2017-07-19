#!/bin/sh

if [ $# -lt 2 ] ;then
    echo "Usage: $0 <upgrade_dir> <target_dir>"
    echo "Example:$0 $UPGRADE_WHATSMINER_PATH $STAGING_DIR/../build_dir/target-arm_cortex-a8+vfpv3_musl-1.1.15_eabi/root-sunxi"
    exit 0;
fi

# Target dir to be upgraded is openwrt/build_dir/target-arm_cortex-a8+vfpv3_musl-1.1.15_eabi/root-sunxi
upgrade_dir=$1
target_dir=$2
tmp_src_dir=$upgrade_dir/upgrade-files/tmp-rootfs

#
# upgrade target_dir with patch_dir
#
echo ""
echo "Upgrading $target_dir by $upgrade_dir"

if [ -d $tmp_src_dir ]; then
	echo "rm -rf $tmp_src_dir"
	rm -rf $tmp_src_dir
fi

cp -af $upgrade_dir/upgrade-files/rootfs $tmp_src_dir

find $tmp_src_dir/ -name *.h3 | xargs rename -f 's/\.h3$//'

# Remove unused files under $target_dir
rm -f $target_dir/etc/config/firewall
rm -f $target_dir/etc/init.d/om-watchdog
rm -f $target_dir/etc/rc.d/S11om-watchdog
rm -f $target_dir/etc/rc.d/K11om-watchdog
rm -f $target_dir/usr/lib/lua/luci/controller/firewall.lua

cp -af $tmp_src_dir/* $target_dir/

if [ -f $upgrade_dir/upgrade-files/bin/boot.fex ]; then
	md5sum $upgrade_dir/upgrade-files/bin/boot.fex | awk '{print $1}' > $target_dir/etc/boot.md5
fi

rm -rf $tmp_src_dir

echo ""
echo "Done"
sync

#!/bin/sh

if [ $# -lt 2 ] ;then
    echo "Usage: $0 <upgrade_dir> <target_dir>"
    echo "Example:$0 upgrade-zynq openwrt/build_dir/target-arm_cortex-a8+vfpv3_musl-1.1.15_eabi/root-sunxi"
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

# Remove unused files under $tmp_src_dir
rm -f $tmp_src_dir/usr/bin/cgminer
rm -f $tmp_src_dir/usr/bin/cgminer-api
find $tmp_src_dir/usr/lib/lua/ -name *.so | xargs rm -f

mv $tmp_src_dir/bin/bitmicro-test.h3 $tmp_src_dir/bin/bitmicro-test
mv $tmp_src_dir/usr/bin/keyd.h3 $tmp_src_dir/usr/bin/keyd
mv $tmp_src_dir/usr/bin/readpower.h3 $tmp_src_dir/usr/bin/readpower
mv $tmp_src_dir/usr/bin/setpower.h3 $tmp_src_dir/usr/bin/setpower
mv $tmp_src_dir/usr/bin/temp-monitor.h3 $tmp_src_dir/usr/bin/temp-monitor

# Remove unused files under $target_dir/etc
rm -f $target_dir/etc/config/firewall
rm -f $target_dir/etc/init.d/om-watchdog
rm -f $target_dir/etc/rc.d/S11om-watchdog
rm -f $target_dir/etc/rc.d/K11om-watchdog

cp -af $tmp_src_dir/* $target_dir/

#rm -rf $tmp_src_dir

echo ""
echo "Done"
sync

#!/bin/sh

if [ $# -lt 2 ] ;then
    echo "Usage: $0 <upgrade_dir> <target_dir>"
    echo "Example:$0 upgrade-zynq openwrt/build_dir/target-arm_cortex-a8+vfpv3_musl-1.1.15_eabi/root-sunxi"
    exit 0;
fi

# Target dir to be upgraded is openwrt/build_dir/target-arm_cortex-a8+vfpv3_musl-1.1.15_eabi/root-sunxi
upgrade_dir=$1
target_dir=$2

#
# upgrade target_dir with patch_dir
#
echo ""
echo "Upgrading $target_dir by $upgrade_dir"

# Remove unused files under $upgrade_dir
rm -f $upgrade_dir/upgrade-files/rootfs/usr/bin/cgminer
rm -f $upgrade_dir/upgrade-files/rootfs/usr/bin/cgminer-api
find $upgrade_dir/upgrade-files/rootfs/usr/lib/lua/ -name *.so | xargs rm -f

cp $upgrade_dir/upgrade-files/rootfs/bin/bitmicro-test.h3 $upgrade_dir/upgrade-files/rootfs/bin/bitmicro-test
cp $upgrade_dir/upgrade-files/rootfs/usr/bin/keyd.h3 $upgrade_dir/upgrade-files/rootfs/usr/bin/keyd
cp $upgrade_dir/upgrade-files/rootfs/usr/bin/readpower.h3 $upgrade_dir/upgrade-files/rootfs/usr/bin/readpower
cp $upgrade_dir/upgrade-files/rootfs/usr/bin/setpower.h3 $upgrade_dir/upgrade-files/rootfs/usr/bin/setpower
cp $upgrade_dir/upgrade-files/rootfs/usr/bin/temp-monitor.h3 $upgrade_dir/upgrade-files/rootfs/usr/bin/temp-monitor

# Remove unused files under $target_dir/etc
rm -f $target_dir/etc/config/firewall
rm -f $target_dir/etc/init.d/om-watchdog
rm -f $target_dir/etc/rc.d/S11om-watchdog
rm -f $target_dir/etc/rc.d/K11om-watchdog

cp -af $upgrade_dir/upgrade-files/rootfs/* $target_dir/

echo ""
echo "Done"
sync

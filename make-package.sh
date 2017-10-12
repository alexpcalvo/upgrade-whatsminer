#!/bin/bash

MACHINE_TYPE="m1-m1s-m2-m3"

VERSION_NUMBER=`cat upgrade-files/rootfs/etc/microbt_release | grep FIRMWARE_VERSION | cut -d"=" -f2 | sed "s/'//g"`

UPGRADE_FULL_PACKAGENAME=upgrade-whatsminer-full-$VERSION_NUMBER.tgz
UPGRADE_FILES_COMMON_PACKAGENAME=upgrade-whatsminer-$MACHINE_TYPE-common-$VERSION_NUMBER.tgz
UPGRADE_FILES_ZYNQ_PACKAGENAME=upgrade-whatsminer-$MACHINE_TYPE-zynq-$VERSION_NUMBER.tgz
UPGRADE_FILES_H3_PACKAGENAME=upgrade-whatsminer-$MACHINE_TYPE-h3-$VERSION_NUMBER.tgz

UPGRADE_FILES_COMMON_FIXED_VOLTAGE_FREQ_PACKAGENAME=upgrade-whatsminer-$MACHINE_TYPE-common-fixed-voltage-freq-$VERSION_NUMBER.tgz

rm -f whatsminer-*.zip upgrade-whatsminer*.tgz

# Create tmp dir
cp -af upgrade-bin .upgrade-bin-bak

# Generate UPGRADE_FULL_PACKAGENAME
./update-upgrade-rootfs.sh
tar zcf $UPGRADE_FULL_PACKAGENAME upgrade.sh upgrade-bin upgrade-rootfs

# Generate UPGRADE_FILES_COMMON_PACKAGENAME
tar zcf $UPGRADE_FILES_COMMON_PACKAGENAME upgrade.sh upgrade-bin upgrade-files

# Generate UPGRADE_FILES_ZYNQ_PACKAGENAME
rm -f upgrade-bin/boot.fex upgrade-bin/old-boot.fex upgrade-bin/BOOT-ZYNQ10.bin upgrade-bin/BOOT-ZYNQ12.bin upgrade-bin/uImage
echo "ZYNQ" > package-type
tar zcf $UPGRADE_FILES_ZYNQ_PACKAGENAME package-type upgrade.sh upgrade-bin upgrade-files

# Generate UPGRADE_FILES_H3_PACKAGENAME
cp -f .upgrade-bin-bak/* upgrade-bin/
rm -f upgrade-bin/BOOT-ZYNQ10.bin upgrade-bin/BOOT-ZYNQ12.bin upgrade-bin/devicetree.dtb upgrade-bin/uImage
echo "H3" > package-type
tar zcf $UPGRADE_FILES_H3_PACKAGENAME package-type upgrade.sh upgrade-bin upgrade-files

# Restore upgrade-bin and remove tmp dir
cp -f .upgrade-bin-bak/* upgrade-bin/
rm -fr .upgrade-bin-bak
rm -f package-type

# Generate UPGRADE_FILES_COMMON_FIXED_VOLTAGE_FREQ_PACKAGENAME
sed -i 's/:1:11500/:0:11500/g' upgrade-files/rootfs/etc/config/powers.m3.v10

tar zcf $UPGRADE_FILES_COMMON_FIXED_VOLTAGE_FREQ_PACKAGENAME upgrade.sh upgrade-bin upgrade-files

git co -- upgrade-files/rootfs/etc/config/powers.m3.v10

#WHATSMINER_PACKAGE_NAME=whatsminer-$MACHINE_TYPE-$VERSION_NUMBER-upgrade
#zip $WHATSMINER_PACKAGE_NAME.zip HOWTO remote-upgrade.sh $UPGRADE_FILES_PACKAGENAME

echo "Generated packages:"
echo "  $UPGRADE_FULL_PACKAGENAME"
echo "  $UPGRADE_FILES_COMMON_PACKAGENAME"
echo "  $UPGRADE_FILES_ZYNQ_PACKAGENAME"
echo "  $UPGRADE_FILES_H3_PACKAGENAME"
echo "  $UPGRADE_FILES_COMMON_FIXED_VOLTAGE_FREQ_PACKAGENAME"

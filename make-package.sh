#!/bin/bash

MACHINE_TYPE="m1-m1s-m2-m3"

VERSION_NUMBER=`cat upgrade-files/rootfs/etc/microbt_release | grep FIRMWARE_VERSION | cut -d"=" -f2 | sed "s/'//g"`

UPGRADE_FULL_PACKAGENAME=upgrade-whatsminer-full-$VERSION_NUMBER.tgz
UPGRADE_FILES_COMMON_PACKAGENAME=upgrade-whatsminer-$MACHINE_TYPE-common-$VERSION_NUMBER.tgz
UPGRADE_FILES_ZYNQ_PACKAGENAME=upgrade-whatsminer-$MACHINE_TYPE-zynq-$VERSION_NUMBER.tgz
UPGRADE_FILES_H3_PACKAGENAME=upgrade-whatsminer-$MACHINE_TYPE-h3-$VERSION_NUMBER.tgz

rm -f upgrade-whatsminer*.tgz

# Generate UPGRADE_FULL_PACKAGENAME
./update-upgrade-rootfs.sh
tar zcf $UPGRADE_FULL_PACKAGENAME upgrade.sh upgrade-bin upgrade-rootfs

# Generate UPGRADE_FILES_COMMON_PACKAGENAME
tar zcf $UPGRADE_FILES_COMMON_PACKAGENAME upgrade.sh upgrade-bin upgrade-files

echo "Generated packages:"
echo "  $UPGRADE_FULL_PACKAGENAME"
echo "  $UPGRADE_FILES_COMMON_PACKAGENAME"

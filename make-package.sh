#!/bin/bash

MACHINE_TYPE="m1-m1s-m2-m3-common"

VERSION_NUMBER=`cat upgrade-files/rootfs/etc/microbt_release | grep FIRMWARE_VERSION | cut -d"=" -f2 | sed "s/'//g"`

UPGRADE_FILES_PACKAGENAME=upgrade-whatsminer-$MACHINE_TYPE-$VERSION_NUMBER.tgz
UPGRADE_ROOTFS_PACKAGENAME=upgrade-whatsminer-rootfs-$VERSION_NUMBER.tgz

rm -f whatsminer-*.zip upgrade-*.tgz

tar zcf $UPGRADE_FILES_PACKAGENAME  upgrade.sh upgrade-bin upgrade-files
tar zcf $UPGRADE_ROOTFS_PACKAGENAME upgrade.sh upgrade-bin upgrade-rootfs

#PACKAGE_NAME=whatsminer-$MACHINE_TYPE-$VERSION_NUMBER-upgrade
#zip $PACKAGE_NAME.zip HOWTO remote-upgrade.sh $UPGRADE_FILES_PACKAGENAME

echo "Generated packages:"
echo "  $UPGRADE_FILES_PACKAGENAME"
echo "  $UPGRADE_ROOTFS_PACKAGENAME"

#!/bin/bash

rm -f upgrade-whatsminer*.tgz

#
# 1. Make auto-adjust-voltage version
#
echo -n "Making auto-adjust-voltage version ... "

VERSION_NUMBER=`cat upgrade-files/rootfs/etc/microbt_release | grep FIRMWARE_VERSION | cut -d"=" -f2 | sed "s/'//g"`
UPGRADE_FULL_PACKAGENAME=upgrade-whatsminer-full-$VERSION_NUMBER.tgz
UPGRADE_FILES_COMMON_PACKAGENAME=upgrade-whatsminer-common-$VERSION_NUMBER.tgz

# Generate UPGRADE_FULL_PACKAGENAME
./update-upgrade-rootfs.sh
tar zcf $UPGRADE_FULL_PACKAGENAME upgrade.sh upgrade-bin upgrade-rootfs

# Generate UPGRADE_FILES_COMMON_PACKAGENAME
tar zcf $UPGRADE_FILES_COMMON_PACKAGENAME upgrade.sh upgrade-bin upgrade-files

echo "OK"
echo "    Package $UPGRADE_FULL_PACKAGENAME is ready."
echo "    Package $UPGRADE_FILES_COMMON_PACKAGENAME is ready."

#
# 2. Make fixed-voltage version
#
echo -n "Making fixed-voltage version ... "

# Update /etc/microbt_release & /etc/config/powers.*
./update-fixed-voltage-version.sh

VERSION_NUMBER=`cat upgrade-files/rootfs/etc/microbt_release | grep FIRMWARE_VERSION | cut -d"=" -f2 | sed "s/'//g"`
UPGRADE_FULL_PACKAGENAME=upgrade-whatsminer-full-$VERSION_NUMBER.tgz
UPGRADE_FILES_COMMON_PACKAGENAME=upgrade-whatsminer-common-$VERSION_NUMBER.tgz

# Generate UPGRADE_FULL_PACKAGENAME
./update-upgrade-rootfs.sh
tar zcf $UPGRADE_FULL_PACKAGENAME upgrade.sh upgrade-bin upgrade-rootfs

# Generate UPGRADE_FILES_COMMON_PACKAGENAME
tar zcf $UPGRADE_FILES_COMMON_PACKAGENAME upgrade.sh upgrade-bin upgrade-files

# Restore /etc/microbt_release & /etc/config/powers.*
./update-fixed-voltage-version.sh restore

echo "OK"
echo "    Package $UPGRADE_FULL_PACKAGENAME is ready."
echo "    Package $UPGRADE_FILES_COMMON_PACKAGENAME is ready."

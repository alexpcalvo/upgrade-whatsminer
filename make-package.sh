#!/bin/bash

if [ "$1" == "fv" ]; then
    echo "Making fixed-voltage version packages"
    ./update-release-version.sh
else
    echo "Making auto-voltage version packages"
fi

VERSION_NUMBER=`cat upgrade-files/rootfs/etc/microbt_release | grep FIRMWARE_VERSION | cut -d"=" -f2 | sed "s/'//g"`

UPGRADE_FULL_PACKAGENAME=upgrade-whatsminer-full-$VERSION_NUMBER.tgz
UPGRADE_FILES_COMMON_PACKAGENAME=upgrade-whatsminer-common-$VERSION_NUMBER.tgz

rm -f upgrade-whatsminer*.tgz

# Generate UPGRADE_FULL_PACKAGENAME
./update-upgrade-rootfs.sh
tar zcf $UPGRADE_FULL_PACKAGENAME upgrade.sh upgrade-bin upgrade-rootfs

# Generate UPGRADE_FILES_COMMON_PACKAGENAME
tar zcf $UPGRADE_FILES_COMMON_PACKAGENAME upgrade.sh upgrade-bin upgrade-files

if [ "$1" == "fv" ]; then
    ./update-release-version.sh restore
fi

echo "Generated packages:"
echo "  $UPGRADE_FULL_PACKAGENAME"
echo "  $UPGRADE_FILES_COMMON_PACKAGENAME"

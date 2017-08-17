#!/bin/bash

MACHINE_TYPE="m1-m1s-m2-m3-common"

VERSION_NUMBER=`cat upgrade-files/rootfs/etc/microbt_release | grep FIRMWARE_VERSION | cut -d"=" -f2 | sed "s/'//g"`

PACKAGE_NAME=whatsminer-$MACHINE_TYPE-$VERSION_NUMBER-upgrade
UPGRADE_PACKAGE=upgrade-whatsminer-$MACHINE_TYPE-$VERSION_NUMBER.tgz

rm -f whatsminer-*.zip upgrade-*.tgz

tar zcf $UPGRADE_PACKAGE upgrade.sh upgrade-files
zip $PACKAGE_NAME.zip HOWTO remote-upgrade.sh $UPGRADE_PACKAGE

echo "Generated package: $PACKAGE_NAME.zip"

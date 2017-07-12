#!/bin/bash

is_h3=false

if [ $# = 1 ] && [ "$1" = "h3" ]; then
    echo "Make package for H3."
    is_h3=true
fi
    
MACHINE_TYPE="m1-m2-common"

VERSION_NUMBER=`cat upgrade-files/rootfs/etc/microbt_release | grep FIRMWARE_VERSION | cut -d"=" -f2 | sed "s/'//g"`

PACKAGE_NAME=whatsminer-$MACHINE_TYPE-$VERSION_NUMBER-upgrade
UPGRADE_PACKAGE=upgrade-whatsminer-$MACHINE_TYPE-$VERSION_NUMBER.tgz

rm -f whatsminer-*.zip upgrade-*.tgz

if [ is_h3 ]; then
	if [ -d tmp_package ];then
		rm -rf tmp_package
	fi

	tmp_upgrade_files="tmp_package/upgrade-files"
	mkdir tmp_package
	cp -afr upgrade-files tmp_package
	rm ${tmp_upgrade_files}/bin/*
	rm ${tmp_upgrade_files}/packages/*
	./prepare-rootfs-for-h3.sh ${tmp_upgrade_files}/rootfs
	tar zcf $UPGRADE_PACKAGE upgrade.sh -C tmp_package upgrade-files
	rm -rf tmp_package
else
	tar zcf $UPGRADE_PACKAGE upgrade.sh upgrade-files
fi

zip $PACKAGE_NAME.zip HOWTO remote-upgrade.sh $UPGRADE_PACKAGE

echo "Generated package: $PACKAGE_NAME.zip"

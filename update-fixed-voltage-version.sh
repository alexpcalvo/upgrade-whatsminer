#!/bin/sh
#

POWERS_FILES="powers.m3.v10 powers.default.m3.v10 powers.m3.v15 powers.default.m3.v15 powers.m3.v20 powers.default.m3.v20 powers.m1.v20 powers.default.m1.v20 powers.common"

if [ "$1" = "restore" ]; then
    git checkout -- upgrade-files/rootfs/etc/microbt_release
    git checkout -- upgrade-rootfs/h3-rootfs/etc/microbt_release
    git checkout -- upgrade-rootfs/zynq-rootfs/etc/microbt_release

    for file in $POWERS_FILES
    do
        git checkout -- upgrade-files/rootfs/etc/config/$file
        git checkout -- upgrade-rootfs/h3-rootfs/etc/config/$file
        git checkout -- upgrade-rootfs/zynq-rootfs/etc/config/$file
    done
else
    for file in $POWERS_FILES
    do
        sed -i "s/:1:/:0:/" upgrade-files/rootfs/etc/config/$file
    done

    sed -i "s/.1'/.2'/g" upgrade-files/rootfs/etc/microbt_release
fi

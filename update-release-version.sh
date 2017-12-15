#!/bin/sh
#

FILE_LIST="powers.m3.v10 powers.default.m3.v10 powers.m3.v15 powers.default.m3.v15 powers.m3.v20 powers.default.m3.v20 powers.m1.v20 powers.default.m1.v20"

if [ "$1" = "restore" ]; then
    echo "Restore upgrade-files/rootfs/etc/microbt_release"
    git checkout -- upgrade-files/rootfs/etc/microbt_release

    for file in $FILE_LIST
    do
        echo "Restore upgrade-files/rootfs/etc/config/$file"
        git checkout -- upgrade-files/rootfs/etc/config/$file
    done
else
    for file in $FILE_LIST
    do
        echo "Update upgrade-files/rootfs/etc/config/$file"
        sed -i "s/:1:/:0:/g" upgrade-files/rootfs/etc/config/$file
    done

    echo "Update upgrade-files/rootfs/etc/microbt_release"
    sed -i "s/.1'/.2'/g" upgrade-files/rootfs/etc/microbt_release
fi

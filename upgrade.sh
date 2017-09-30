#!/bin/sh
#
# Upgrade script.
#

# Detect control board type
cpuinfo=`cat /proc/cpuinfo | grep "Xilinx Zynq Platform"`
if [ "$cpuinfo" != "" ]; then
    isH3Platform=false

	memsize=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`

    if [ $memsize -le 262144 ]; then
        control_board="ZYNQ-CB12"
    else
        control_board="ZYNQ-CB10"
    fi
else
    cpuinfo=`cat /proc/cpuinfo | grep sun8i`
    if [ "$cpuinfo" != "" ]; then
        isH3Platform=true
        control_board="H3"
    else
        control_board="unknown"
    fi
fi

echo "Detected machine type: control_board=$control_board"

if [ "$control_board" = "unknown" ]; then
    echo "*********************************************************************"
    echo "Unknown control board type, quit the upgrade process."
    echo "*********************************************************************"
    exit 0
fi

if [ -f /tmp/package-type ]; then
    package_type=`cat /tmp/package-type`

    if [ "$package_type" = "ZYNQ" -a "$isH3Platform" = true ]; then
        echo "****************************************************************************************************"
        echo "Package type ($package_type) mismatched with control board type ($control_board), quit the upgrade process."
        echo "****************************************************************************************************"
        rm -fr /tmp/package-type /tmp/upgrade-bin /tmp/upgrade-files
        exit 0
    fi
    if [ "$package_type" = "H3" -a "$isH3Platform" = false ]; then
        echo "****************************************************************************************************"
        echo "Package type ($package_type) mismatched with control board type ($control_board), quit the upgrade process."
        echo "****************************************************************************************************"
        rm -fr /tmp/package-type /tmp/upgrade-bin /tmp/upgrade-files
        exit 0
    fi
fi

# Compare two files.
# Return 'no' if these two files are the same,
# else return 'yes'.
diff_files() {
    if [ ! -f $1 -o ! -f $2 ]; then
        echo "yes"
    else
        cmp $1 $2 > /tmp/upgrade-file.diff 2>&1
        DIFF=`cat /tmp/upgrade-file.diff`
        if [ "$DIFF" = "" ]; then
            echo "no"
        else
            echo "yes"
        fi
    fi
}

#
# Kill services
#
killall -9 crond >/dev/null 2>&1
killall -9 system-monitor >/dev/null 2>&1
killall -9 temp-monitor >/dev/null 2>&1
killall -9 keyd >/dev/null 2>&1
killall -9 cgminer >/dev/null 2>&1
killall -9 uhttpd >/dev/null 2>&1
killall -9 ntpd >/dev/null 2>&1
killall -9 udevd >/dev/null 2>&1

#
# Prepare rootfs
#
if [ "$isH3Platform" = true ]; then
    # H3: 1) remove useless files; 2) replace xxx with xxx.h3
    rm -f `ls /tmp/upgrade-bin/* | grep -v boot.fex`

    if [ -d /tmp/upgrade-files ]; then
        rm -f /tmp/upgrade-files/packages/*

        for file in $(find /tmp/upgrade-files/rootfs -name "*.h3")
        do
            newfile=`echo $file | sed 's/\.h3$//'`
            mv $file $newfile
        done
    fi

    boot_part=`cat /proc/cmdline | grep boot_part`
    if [ "$boot_part" = "" ]; then
        rm /tmp/upgrade-bin/boot.fex
        mv /tmp/upgrade-bin/old-boot.fex /tmp/upgrade-bin/boot.fex
    fi
else
    # ZYNQ: 1) remove useless files for h3
    rm -f /tmp/upgrade-bin/boot.fex
    rm -f /tmp/upgrade-bin/old-boot.fex
    if [ -d /tmp/upgrade-files/rootfs ]; then
        find /tmp/upgrade-files/rootfs -name "*.h3" | xargs rm -f
    fi
fi

#
# 1. Verify and upgrade /tmp/upgrade-bin/*
#

# Detected files
if [ "$control_board" = "ZYNQ-CB12" ]; then
    BOOTFILE="BOOT-ZYNQ12"
else
    BOOTFILE="BOOT-ZYNQ10"
fi

# boot (mtd1)
if [ -f /tmp/upgrade-bin/$BOOTFILE.bin ]; then
    # verify with mtd data
    mtd verify /tmp/upgrade-bin/$BOOTFILE.bin /dev/mtd1 2>/tmp/.mtd-verify-stderr.txt
    result_success=`cat /tmp/.mtd-verify-stderr.txt | grep Success`
    if [ "$result_success" != "Success" ]; then
        # upgrade to mtd
        echo "Upgrading $BOOTFILE.bin to /dev/mtd1"
        mtd erase /dev/mtd1
        mtd write /tmp/upgrade-bin/$BOOTFILE.bin /dev/mtd1
    fi
fi

# kernel (mtd4 for ZYNQ)
if [ -f /tmp/upgrade-bin/uImage ]; then
    # verify with mtd data
    mtd verify /tmp/upgrade-bin/uImage /dev/mtd4 2>/tmp/.mtd-verify-stderr.txt
    result_success=`cat /tmp/.mtd-verify-stderr.txt | grep Success`
    if [ "$result_success" != "Success" ]; then
        # upgrade to mtd
        echo "Upgrading kernel.bin to /dev/mtd4"
        mtd erase /dev/mtd4
        mtd write /tmp/upgrade-bin/uImage /dev/mtd4
    fi
fi

# kernel (nandc for H3)
if [ -f /tmp/upgrade-bin/boot.fex ]; then
    new_md5=`md5sum /tmp/upgrade-bin/boot.fex | awk '{print $1}'`
    if [ "`cat /etc/boot.md5`" != "$new_md5" ]; then
        echo "Upgrading boot.fex to /dev/nandc"
        cat /tmp/upgrade-bin/boot.fex > /dev/nandc
        echo $new_md5 > /etc/boot.md5
    fi
fi

# devicetree (mtd5)
if [ -f /tmp/upgrade-bin/devicetree.dtb ]; then
    # verify with mtd data
    mtd verify /tmp/upgrade-bin/devicetree.dtb /dev/mtd5 2>/tmp/.mtd-verify-stderr.txt
    result_success=`cat /tmp/.mtd-verify-stderr.txt | grep Success`
    if [ "$result_success" != "Success" ]; then
        # upgrade to mtd
        echo "Upgrading devicetree.bin to /dev/mtd5"
        mtd erase /dev/mtd5
        mtd write /tmp/upgrade-bin/devicetree.dtb /dev/mtd5
    fi
fi

#
# 2. Upgrade /tmp/upgrade-rootfs/
#
if [ -d /tmp/upgrade-rootfs ]; then
    echo "Upgrading rootfs ..."

    rm -fr /usr/lib/lua

    if [ "$isH3Platform" = true ]; then
        cp -afr /tmp/upgrade-rootfs/h3-rootfs/* /
    else
        cp -afr /tmp/upgrade-rootfs/zynq-rootfs/* /
    fi

    # Confirm file attributes again
    chmod 555 /usr/bin/cgminer
    chmod 555 /usr/bin/cgminer-api
    chmod 555 /usr/bin/cgminer-monitor
    chmod 555 /usr/bin/miner-detect-common
    chmod 555 /usr/bin/detect-miner-info
    chmod 555 /usr/bin/lua-detect-version
    chmod 555 /usr/bin/keyd
    chmod 555 /usr/bin/readpower
    chmod 555 /usr/bin/setpower
    chmod 555 /usr/bin/system-monitor
    chmod 555 /usr/bin/remote-daemon
    chmod 555 /etc/init.d/boot
    chmod 555 /etc/init.d/cgminer
    chmod 555 /etc/init.d/detect-cgminer-config
    chmod 555 /etc/init.d/remote-daemon
    chmod 555 /etc/init.d/system-monitor
    chmod 555 /etc/init.d/sdcard-upgrade
    chmod 555 /bin/bitmicro-test
    chmod 444 /etc/microbt_release
    chmod 444 /etc/cgminer_version

    echo "Done, reboot control board ..."

    # reboot or sync may be blocked under some conditions
    # so we call 'reboot -n -f' background to force rebooting
    # after sleep timeout
    sleep 20 && reboot -n -f &

    sync
    mount /dev/root -o remount,ro >/dev/null 2>&1
    reboot
    exit 1
fi

#
# 3. Upgrade /tmp/upgrade-files/
#

echo "Upgrading files ..."

# /etc/config/system
if [ -f /tmp/upgrade-files/rootfs/etc/config/system ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/system /etc/config/system`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/system"
        chmod 644 /etc/config/system >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/system /etc/config/system
        chmod 444 /etc/config/system # readonly
    fi
fi

# /etc/config/powers.m3.v12
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.m3.v12 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.m3.v12 /etc/config/powers.m3.v12`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.m3.v12"
        chmod 644 /etc/config/powers.m3.v12 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.m3.v12 /etc/config/powers.m3.v12
        chmod 444 /etc/config/powers.m3.v12 # readonly
    fi
fi
# /etc/config/powers.default.m3.v12
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v12 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v12 /etc/config/powers.default.m3.v12`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.default.m3.v12"
        chmod 644 /etc/config/powers.default.m3.v12 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v12 /etc/config/powers.default.m3.v12
        chmod 444 /etc/config/powers.default.m3.v12 # readonly
    fi
fi

# /etc/config/powers.m3.v11
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.m3.v11 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.m3.v11 /etc/config/powers.m3.v11`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.m3.v11"
        chmod 644 /etc/config/powers.m3.v11 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.m3.v11 /etc/config/powers.m3.v11
        chmod 444 /etc/config/powers.m3.v11 # readonly
    fi
fi
# /etc/config/powers.default.m3.v11
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v11 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v11 /etc/config/powers.default.m3.v11`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.default.m3.v11"
        chmod 644 /etc/config/powers.default.m3.v11 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v11 /etc/config/powers.default.m3.v11
        chmod 444 /etc/config/powers.default.m3.v11 # readonly
    fi
fi

# /etc/config/powers.m3.v10
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.m3.v10 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.m3.v10 /etc/config/powers.m3.v10`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.m3.v10"
        chmod 644 /etc/config/powers.m3.v10 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.m3.v10 /etc/config/powers.m3.v10
        chmod 444 /etc/config/powers.m3.v10 # readonly
    fi
fi
# /etc/config/powers.default.m3.v10
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v10 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v10 /etc/config/powers.default.m3.v10`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.default.m3.v10"
        chmod 644 /etc/config/powers.default.m3.v10 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m3.v10 /etc/config/powers.default.m3.v10
        chmod 444 /etc/config/powers.default.m3.v10 # readonly
    fi
fi

# /etc/config/powers.m2
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.m2 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.m2 /etc/config/powers.m2`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.m2"
        chmod 644 /etc/config/powers.m2 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.m2 /etc/config/powers.m2
        chmod 444 /etc/config/powers.m2 # readonly
    fi
fi
# /etc/config/powers.default.m2
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m2 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.default.m2 /etc/config/powers.default.m2`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.default.m2"
        chmod 644 /etc/config/powers.default.m2 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m2 /etc/config/powers.default.m2
        chmod 444 /etc/config/powers.default.m2 # readonly
    fi
fi

# /etc/config/powers.m1s
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.m1s ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.m1s /etc/config/powers.m1s`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.m1s"
        chmod 644 /etc/config/powers.m1s >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.m1s /etc/config/powers.m1s
        chmod 444 /etc/config/powers.m1s # readonly
    fi
fi
# /etc/config/powers.default.m1s
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m1s ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.default.m1s /etc/config/powers.default.m1s`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.default.m1s"
        chmod 644 /etc/config/powers.default.m1s >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m1s /etc/config/powers.default.m1s
        chmod 444 /etc/config/powers.default.m1s # readonly
    fi
fi

# /etc/config/powers.m1
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.m1 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.m1 /etc/config/powers.m1`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.m1"
        chmod 644 /etc/config/powers.m1 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.m1 /etc/config/powers.m1
        chmod 444 /etc/config/powers.m1 # readonly
    fi
fi
# /etc/config/powers.default.m1
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m1 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.default.m1 /etc/config/powers.default.m1`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.default.m1"
        chmod 644 /etc/config/powers.default.m1 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m1 /etc/config/powers.default.m1
        chmod 444 /etc/config/powers.default.m1 # readonly
    fi
fi

# /etc/config/powers.m0
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.m0 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.m0 /etc/config/powers.m0`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.m0"
        chmod 644 /etc/config/powers.m0 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.m0 /etc/config/powers.m0
        chmod 444 /etc/config/powers.m0 # readonly
    fi
fi
# /etc/config/powers.default.m0
if [ -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m0 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/powers.default.m0 /etc/config/powers.default.m0`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/powers.default.m0"
        chmod 644 /etc/config/powers.default.m0 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/powers.default.m0 /etc/config/powers.default.m0
        chmod 444 /etc/config/powers.default.m0 # readonly
    fi
fi

# /etc/config/network.default
if [ -f /tmp/upgrade-files/rootfs/etc/config/network.default ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/network.default /etc/config/network.default`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/network.default"
        chmod 644 /etc/config/network.default >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/network.default /etc/config/network.default
        chmod 444 /etc/config/network.default # readonly
    fi
fi

# /etc/config/pools.default
if [ -f /tmp/upgrade-files/rootfs/etc/config/pools.default ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/pools.default /etc/config/pools.default`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/pools.default"
        chmod 644 /etc/config/pools.default >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/pools.default /etc/config/pools.default
        chmod 444 /etc/config/pools.default # readonly
    fi
fi

# /etc/config/pools
if [ ! -f /etc/config/pools ]; then
    echo "Upgrading /etc/config/pools"

    # Special handling. Reserve user pools configuration
    # /etc/config/cgminer -> /etc/config/pools
    fromfile="/etc/config/cgminer"
    tofile="/etc/config/pools"
    echo "" > $tofile
    echo "config pools 'default'" >> $tofile

    line=`cat $fromfile | grep "ntp_enable"`
    echo "$line" >> $tofile
    line=`cat $fromfile | grep "ntp_pools"`
    echo "$line" >> $tofile

    line=`cat $fromfile | grep "pool1url"`
    echo "$line" >> $tofile
    line=`cat $fromfile | grep "pool1user"`
    echo "$line" >> $tofile
    line=`cat $fromfile | grep "pool1pw"`
    echo "$line" >> $tofile

    line=`cat $fromfile | grep "pool2url"`
    echo "$line" >> $tofile
    line=`cat $fromfile | grep "pool2user"`
    echo "$line" >> $tofile
    line=`cat $fromfile | grep "pool2pw"`
    echo "$line" >> $tofile

    line=`cat $fromfile | grep "pool3url"`
    echo "$line" >> $tofile
    line=`cat $fromfile | grep "pool3user"`
    echo "$line" >> $tofile
    line=`cat $fromfile | grep "pool3pw"`
    echo "$line" >> $tofile

    chmod 644 /etc/config/pools
fi

# Upgrade /etc/config/cgminer after updating pools

# /etc/config/cgminer.m3.v12
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v12 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v12 /etc/config/cgminer.m3.v12`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.m3.v12 to /etc/config/cgminer.m3.v12"
        chmod 644 /etc/config/cgminer.m3.v12 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v12 /etc/config/cgminer.m3.v12
        chmod 444 /etc/config/cgminer.m3.v12 # readonly
    fi
fi
# /etc/config/cgminer.default.m3.v12
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v12 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v12 /etc/config/cgminer.default.m3.v12`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.m3.v12 to /etc/config/cgminer.default.m3.v12"
        chmod 644 /etc/config/cgminer.default.m3.v12 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v12 /etc/config/cgminer.default.m3.v12
        chmod 444 /etc/config/cgminer.default.m3.v12 # readonly
    fi
fi

# /etc/config/cgminer.m3.v11
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v11 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v11 /etc/config/cgminer.m3.v11`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.m3.v11 to /etc/config/cgminer.m3.v11"
        chmod 644 /etc/config/cgminer.m3.v11 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v11 /etc/config/cgminer.m3.v11
        chmod 444 /etc/config/cgminer.m3.v11 # readonly
    fi
fi
# /etc/config/cgminer.default.m3.v11
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v11 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v11 /etc/config/cgminer.default.m3.v11`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.m3.v11 to /etc/config/cgminer.default.m3.v11"
        chmod 644 /etc/config/cgminer.default.m3.v11 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v11 /etc/config/cgminer.default.m3.v11
        chmod 444 /etc/config/cgminer.default.m3.v11 # readonly
    fi
fi

# /etc/config/cgminer.m3.v10
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v10 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v10 /etc/config/cgminer.m3.v10`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.m3.v10 to /etc/config/cgminer.m3.v10"
        chmod 644 /etc/config/cgminer.m3.v10 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m3.v10 /etc/config/cgminer.m3.v10
        chmod 444 /etc/config/cgminer.m3.v10 # readonly
    fi
fi
# /etc/config/cgminer.default.m3.v10
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v10 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v10 /etc/config/cgminer.default.m3.v10`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.m3.v10 to /etc/config/cgminer.default.m3.v10"
        chmod 644 /etc/config/cgminer.default.m3.v10 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m3.v10 /etc/config/cgminer.default.m3.v10
        chmod 444 /etc/config/cgminer.default.m3.v10 # readonly
    fi
fi

# /etc/config/cgminer.m2
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m2 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.m2 /etc/config/cgminer.m2`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.m2 to /etc/config/cgminer.m2"
        chmod 644 /etc/config/cgminer.m2 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m2 /etc/config/cgminer.m2
        chmod 444 /etc/config/cgminer.m2 # readonly
    fi
fi
# /etc/config/cgminer.default.m2
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m2 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m2 /etc/config/cgminer.default.m2`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.m2 to /etc/config/cgminer.default.m2"
        chmod 644 /etc/config/cgminer.default.m2 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m2 /etc/config/cgminer.default.m2
        chmod 444 /etc/config/cgminer.default.m2 # readonly
    fi
fi

# /etc/config/cgminer.m1s
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m1s ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.m1s /etc/config/cgminer.m1s`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.m1s to /etc/config/cgminer.m1s"
        chmod 644 /etc/config/cgminer.m1s >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m1s /etc/config/cgminer.m1s
        chmod 444 /etc/config/cgminer.m1s # readonly
    fi
fi
# /etc/config/cgminer.default.m1s
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m1s ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m1s /etc/config/cgminer.default.m1s`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.m1s to /etc/config/cgminer.default.m1s"
        chmod 644 /etc/config/cgminer.default.m1s >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m1s /etc/config/cgminer.default.m1s
        chmod 444 /etc/config/cgminer.default.m1s # readonly
    fi
fi

# /etc/config/cgminer.m1
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m1 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.m1 /etc/config/cgminer.m1`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.m1 to /etc/config/cgminer.m1"
        chmod 644 /etc/config/cgminer.m1 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m1 /etc/config/cgminer.m1
        chmod 444 /etc/config/cgminer.m1 # readonly
    fi
fi
# /etc/config/cgminer.default.m1
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m1 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m1 /etc/config/cgminer.default.m1`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.m1 to /etc/config/cgminer.default.m1"
        chmod 644 /etc/config/cgminer.default.m1 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m1 /etc/config/cgminer.default.m1
        chmod 444 /etc/config/cgminer.default.m1 # readonly
    fi
fi

# /etc/config/cgminer.m0
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m0 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.m0 /etc/config/cgminer.m0`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.m0 to /etc/config/cgminer.m0"
        chmod 644 /etc/config/cgminer.m0 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.m0 /etc/config/cgminer.m0
        chmod 444 /etc/config/cgminer.m0 # readonly
    fi
fi
# /etc/config/cgminer.default.m0
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m0 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m0 /etc/config/cgminer.default.m0`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.m0 to /etc/config/cgminer.default.m0"
        chmod 644 /etc/config/cgminer.default.m0 >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.m0 /etc/config/cgminer.default.m0
        chmod 444 /etc/config/cgminer.default.m0 # readonly
    fi
fi

# /etc/init.d/boot
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/boot ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/boot /etc/init.d/boot`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/boot"
        chmod 755 /etc/init.d/boot
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/boot /etc/init.d/boot
        chmod 555 /etc/init.d/boot
    fi
fi

# /etc/init.d/detect-cgminer-config
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/detect-cgminer-config ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/detect-cgminer-config /etc/init.d/detect-cgminer-config`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/detect-cgminer-config"
        chmod 755 /etc/init.d/detect-cgminer-config
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/detect-cgminer-config /etc/init.d/detect-cgminer-config
        chmod 555 /etc/init.d/detect-cgminer-config
        cd /etc/rc.d/
        ln -s ../init.d/detect-cgminer-config S80detect-cgminer-config >/dev/null 2>&1
        cd - >/dev/null
    fi
fi

# /etc/crontabs/root
if [ -f /tmp/upgrade-files/rootfs/etc/crontabs/root ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/crontabs/root /etc/crontabs/root`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/crontabs/root"
        chmod 644 /etc/crontabs/root
        cp -f /tmp/upgrade-files/rootfs/etc/crontabs/root /etc/crontabs/root
        chmod 444 /etc/crontabs/root
    fi
fi

# /etc/init.d/cgminer
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/cgminer ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/cgminer /etc/init.d/cgminer`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/cgminer"
        chmod 755 /etc/init.d/cgminer
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/cgminer /etc/init.d/cgminer
        chmod 555 /etc/init.d/cgminer
    fi
fi

# /etc/init.d/system-monitor
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/system-monitor ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/system-monitor /etc/init.d/system-monitor`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/system-monitor"
        chmod 755 /etc/init.d/system-monitor
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/system-monitor /etc/init.d/system-monitor
        chmod 555 /etc/init.d/system-monitor
        cd /etc/rc.d/
        ln -s ../init.d/system-monitor S90system-monitor >/dev/null 2>&1
        cd - >/dev/null
    fi
fi

# /etc/init.d/sdcard-upgrade
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/sdcard-upgrade ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/sdcard-upgrade /etc/init.d/sdcard-upgrade`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/sdcard-upgrade"
        chmod 755 /etc/init.d/sdcard-upgrade
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/sdcard-upgrade /etc/init.d/sdcard-upgrade
        chmod 555 /etc/init.d/sdcard-upgrade
        cd /etc/rc.d/
        ln -s ../init.d/sdcard-upgrade S97sdcard-upgrade >/dev/null 2>&1
        cd - >/dev/null
    fi
fi

# /etc/init.d/remote-daemon
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/remote-daemon ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/remote-daemon /etc/init.d/remote-daemon`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/remote-daemon"
        chmod 755 /etc/init.d/remote-daemon
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/remote-daemon /etc/init.d/remote-daemon
        chmod 555 /etc/init.d/remote-daemon
        cd /etc/rc.d/
        ln -s ../init.d/remote-daemon S90remote-daemon >/dev/null 2>&1
        cd - >/dev/null
    fi
fi

# /usr/bin/cgminer
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/cgminer /usr/bin/cgminer`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/cgminer"
        chmod 755 /usr/bin/cgminer
        cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer /usr/bin/cgminer
        chmod 555 /usr/bin/cgminer
    fi
fi

# /usr/bin/cgminer-api
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-api ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/cgminer-api /usr/bin/cgminer-api`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/cgminer-api"
        chmod 755 /usr/bin/cgminer-api
        cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-api /usr/bin/cgminer-api
        chmod 555 /usr/bin/cgminer-api
    fi
fi

# /usr/bin/cgminer-monitor
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-monitor ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/cgminer-monitor /usr/bin/cgminer-monitor`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/cgminer-monitor"
        chmod 755 /usr/bin/cgminer-monitor
        cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-monitor /usr/bin/cgminer-monitor
        chmod 555 /usr/bin/cgminer-monitor
    fi
fi

# /usr/bin/system-monitor
if [ -f /tmp/upgrade-files/rootfs/usr/bin/system-monitor ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/system-monitor /usr/bin/system-monitor`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/system-monitor"
        chmod 755 /usr/bin/system-monitor
        cp -f /tmp/upgrade-files/rootfs/usr/bin/system-monitor /usr/bin/system-monitor
        chmod 555 /usr/bin/system-monitor
    fi
fi

# /usr/bin/setpower
if [ -f /tmp/upgrade-files/rootfs/usr/bin/setpower ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/setpower /usr/bin/setpower`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/setpower"
        chmod 755 /usr/bin/setpower
        cp -f /tmp/upgrade-files/rootfs/usr/bin/setpower /usr/bin/setpower
        chmod 555 /usr/bin/setpower
    fi
fi

# /usr/bin/readpower
if [ -f /tmp/upgrade-files/rootfs/usr/bin/readpower ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/readpower /usr/bin/readpower`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/readpower"
        chmod 755 /usr/bin/readpower
        cp -f /tmp/upgrade-files/rootfs/usr/bin/readpower /usr/bin/readpower
        chmod 555 /usr/bin/readpower
    fi
fi

# /usr/bin/keyd
if [ -f /tmp/upgrade-files/rootfs/usr/bin/keyd ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/keyd /usr/bin/keyd`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/keyd"
        chmod 755 /usr/bin/keyd
        cp -f /tmp/upgrade-files/rootfs/usr/bin/keyd /usr/bin/keyd
        chmod 555 /usr/bin/keyd
    fi
fi

# /usr/bin/remote-daemon
if [ -f /tmp/upgrade-files/rootfs/usr/bin/remote-daemon ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/remote-daemon /usr/bin/remote-daemon`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/remote-daemon"
        chmod 755 /usr/bin/remote-daemon
        cp -f /tmp/upgrade-files/rootfs/usr/bin/remote-daemon /usr/bin/remote-daemon
        chmod 555 /usr/bin/remote-daemon
    fi
fi

# /usr/bin/miner-detect-common
if [ -f /tmp/upgrade-files/rootfs/usr/bin/miner-detect-common ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/miner-detect-common /usr/bin/miner-detect-common`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/miner-detect-common"
        chmod 755 /usr/bin/miner-detect-common
        cp -f /tmp/upgrade-files/rootfs/usr/bin/miner-detect-common /usr/bin/miner-detect-common
        chmod 555 /usr/bin/miner-detect-common
    fi
fi

# /usr/bin/detect-miner-info
if [ -f /tmp/upgrade-files/rootfs/usr/bin/detect-miner-info ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/detect-miner-info /usr/bin/detect-miner-info`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/detect-miner-info"
        chmod 755 /usr/bin/detect-miner-info
        cp -f /tmp/upgrade-files/rootfs/usr/bin/detect-miner-info /usr/bin/detect-miner-info
        chmod 555 /usr/bin/detect-miner-info
    fi
fi

# /usr/bin/lua-detect-version
if [ -f /tmp/upgrade-files/rootfs/usr/bin/lua-detect-version ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/lua-detect-version /usr/bin/lua-detect-version`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/lua-detect-version"
        chmod 755 /usr/bin/lua-detect-version
        cp -f /tmp/upgrade-files/rootfs/usr/bin/lua-detect-version /usr/bin/lua-detect-version
        chmod 555 /usr/bin/lua-detect-version
    fi
fi

# /usr/lib/lua
if [ -d /tmp/upgrade-files/rootfs/usr/lib/lua ]; then
    if [ -d /usr/lib/lua ]; then
        cd /tmp/upgrade-files/rootfs/usr/lib/lua
        find ./ -type f -print0 | xargs -0 md5sum | sort > /tmp/lua-md5sum-new.txt
        cd /usr/lib/lua
        find ./ -type f -print0 | xargs -0 md5sum | sort > /tmp/lua-md5sum-cur.txt
        DIFF=`cmp /tmp/lua-md5sum-new.txt /tmp/lua-md5sum-cur.txt`
        if [ "$DIFF" != "" ]; then
            echo "Upgrading /usr/lib/lua"
            rm -fr /usr/lib/lua
            cp -afr /tmp/upgrade-files/rootfs/usr/lib/lua /usr/lib/
        fi
    else
        echo "Upgrading /usr/lib/lua"
        rm -fr /usr/lib/lua
        cp -afr /tmp/upgrade-files/rootfs/usr/lib/lua /usr/lib/
    fi
fi

# /bin/bitmicro-test, test-readchipid, test-sendgoldenwork, test-hashboard
if [ -f /tmp/upgrade-files/rootfs/bin/bitmicro-test ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/bin/bitmicro-test /bin/bitmicro-test`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /bin/bitmicro-test"
        rm -f /bin/bitmicrotest
        chmod 755 /bin/bitmicro-test
        cp -f /tmp/upgrade-files/rootfs/bin/bitmicro-test /bin/bitmicro-test
        chmod 555 /bin/bitmicro-test
    fi
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-readchipid ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/bin/test-readchipid /bin/test-readchipid`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /bin/test-readchipid"
        chmod 755 /bin/test-readchipid
        cp -f /tmp/upgrade-files/rootfs/bin/test-readchipid /bin/test-readchipid
        chmod 555 /bin/test-readchipid
    fi
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-sendgoldenwork ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/bin/test-sendgoldenwork /bin/test-sendgoldenwork`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /bin/test-sendgoldenwork"
        chmod 755 /bin/test-sendgoldenwork
        cp -f /tmp/upgrade-files/rootfs/bin/test-sendgoldenwork /bin/test-sendgoldenwork
        chmod 555 /bin/test-sendgoldenwork
    fi
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-hashboard ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/bin/test-hashboard /bin/test-hashboard`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /bin/test-hashboard"
        chmod 755 /bin/test-hashboard
        cp -f /tmp/upgrade-files/rootfs/bin/test-hashboard /bin/test-hashboard
        chmod 555 /bin/test-hashboard
    fi
fi

if [ -f /tmp/upgrade-files/rootfs/usr/bin/pre-reboot ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/pre-reboot /usr/bin/pre-reboot`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/pre-reboot"
        chmod 755 /usr/bin/pre-reboot >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/usr/bin/pre-reboot /usr/bin/pre-reboot
        chmod 555 /usr/bin/pre-reboot
    fi
fi

if [ -f /tmp/upgrade-files/rootfs/usr/bin/restore-factory-settings ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/restore-factory-settings /usr/bin/restore-factory-settings`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/restore-factory-settings"
        chmod 755 /usr/bin/restore-factory-settings >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/usr/bin/restore-factory-settings /usr/bin/restore-factory-settings
        chmod 555 /usr/bin/restore-factory-settings
    fi
fi

if [ -f /tmp/upgrade-files/rootfs/etc/shadow ]; then
	if [ ! -f /etc/shadow ]; then
		echo "Upgrading /etc/shadow"
		cp -f /tmp/upgrade-files/rootfs/etc/shadow /etc/shadow
        chmod 644 /etc/shadow
	fi
fi
if [ -f /tmp/upgrade-files/rootfs/etc/shadow.default ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/shadow.default /etc/shadow.default`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/shadow.default"
        chmod 755 /etc/shadow.default
        cp -f /tmp/upgrade-files/rootfs/etc/shadow.default /etc/shadow.default
        chmod 555 /etc/shadow.default
    fi
fi

# sensors and relative libs
if [ ! -f /usr/sbin/sensors ]; then
    if [ -f /tmp/upgrade-files/packages/libsysfs_2.1.0-2_zynq.ipk ]; then
        echo "Installing libsysfs"
        opkg install /tmp/upgrade-files/packages/libsysfs_2.1.0-2_zynq.ipk
    fi
    if [ -f /tmp/upgrade-files/packages/sysfsutils_2.1.0-2_zynq.ipk ]; then
        echo "Installing sysfsutils"
        opkg install /tmp/upgrade-files/packages/sysfsutils_2.1.0-2_zynq.ipk
    fi
    if [ -f /tmp/upgrade-files/packages/libsensors_3.3.5-3_zynq.ipk ]; then
        echo "Installing libsensors"
        opkg install /tmp/upgrade-files/packages/libsensors_3.3.5-3_zynq.ipk
    fi
    if [ -f /tmp/upgrade-files/packages/lm-sensors_3.3.5-3_zynq.ipk ]; then
        echo "Installing lm-sensors"
        opkg install /tmp/upgrade-files/packages/lm-sensors_3.3.5-3_zynq.ipk
    fi
fi

# Remove unused files
if [ -f /etc/config/firewall ]; then
    rm -f /etc/config/firewall
fi
if [ -f /etc/init.d/om-watchdog ]; then
    rm -f /etc/init.d/om-watchdog
fi
if [ -f /etc/rc.d/S11om-watchdog ]; then
    rm -f /etc/rc.d/S11om-watchdog
fi
if [ -f /etc/rc.d/K11om-watchdog ]; then
    rm -f /etc/rc.d/K11om-watchdog
fi

if [ -f /etc/rc.d/S90temp-monitor ]; then
    rm -f /etc/rc.d/S90temp-monitor
fi
if [ -f /etc/init.d/temp-monitor ]; then
    rm -f /etc/init.d/temp-monitor
fi
if [ -f /usr/bin/temp-monitor ]; then
    rm -f /usr/bin/temp-monitor
fi

if [ -f /usr/bin/phonixtest ]; then
    rm -f /usr/bin/phonixtest
fi

if [ -f /usr/bin/remote-update-cgminer ]; then
    rm -f /usr/bin/remote-update-cgminer
fi

if [ -f /etc/init.d/boot.bak ]; then
    rm -f /etc/init.d/boot.bak
fi

if [ -f /etc/config/powers.hash10 ]; then
    rm -f /etc/config/powers.hash10
fi
if [ -f /etc/config/powers.hash12 ]; then
    rm -f /etc/config/powers.hash12
fi
if [ -f /etc/config/powers.hash20 ]; then
    rm -f /etc/config/powers.hash20
fi
if [ -f /etc/config/powers.alb10 ]; then
    rm -f /etc/config/powers.alb10
fi
if [ -f /etc/config/powers.alb20 ]; then
    rm -f /etc/config/powers.alb20
fi

if [ -f /etc/config/cgminer.hash10 ]; then
    rm -f /etc/config/cgminer.hash10
fi
if [ -f /etc/config/cgminer.hash12 ]; then
    rm -f /etc/config/cgminer.hash12
fi
if [ -f /etc/config/cgminer.hash20 ]; then
    rm -f /etc/config/cgminer.hash20
fi
if [ -f /etc/config/cgminer.alb10 ]; then
    rm -f /etc/config/cgminer.alb10
fi
if [ -f /etc/config/cgminer.alb20 ]; then
    rm -f /etc/config/cgminer.alb20
fi

if [ -f /etc/config/cgminer.default.hash10 ]; then
    rm -f /etc/config/cgminer.default.hash10
fi
if [ -f /etc/config/cgminer.default.hash12 ]; then
    rm -f /etc/config/cgminer.default.hash12
fi
if [ -f /etc/config/cgminer.default.hash20 ]; then
    rm -f /etc/config/cgminer.default.hash20
fi
if [ -f /etc/config/cgminer.default.alb10 ]; then
    rm -f /etc/config/cgminer.default.alb10
fi
if [ -f /etc/config/cgminer.default.alb20 ]; then
    rm -f /etc/config/cgminer.default.alb20
fi

if [ -f /etc/config/powers.m3 ]; then
    rm -f /etc/config/powers.m3
fi
if [ -f /etc/config/powers.default.m3 ]; then
    rm -f /etc/config/powers.default.m3
fi
if [ -f /etc/config/powers.m3f ]; then
    rm -f /etc/config/powers.m3f
fi
if [ -f /etc/config/powers.default.m3f ]; then
    rm -f /etc/config/powers.default.m3f
fi
if [ -f /etc/config/cgminer.m3 ]; then
    rm -f /etc/config/cgminer.m3
fi
if [ -f /etc/config/cgminer.default.m3 ]; then
    rm -f /etc/config/cgminer.default.m3
fi
if [ -f /etc/config/cgminer.m3f ]; then
    rm -f /etc/config/cgminer.m3f
fi
if [ -f /etc/config/cgminer.default.m3f ]; then
    rm -f /etc/config/cgminer.default.m3f
fi

if [ -f /etc/config/firewall.unused ]; then
    rm -f /etc/config/firewall.unused
fi

# /etc/microbt_release
if [ -f /tmp/upgrade-files/rootfs/etc/microbt_release ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/microbt_release /etc/microbt_release`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/microbt_release"
        chmod 644 /etc/microbt_release >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/microbt_release /etc/
        chmod 444 /etc/microbt_release # readonly
    fi
fi
# /etc/cgminer_version
if [ -f /tmp/upgrade-files/rootfs/etc/cgminer_version ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/cgminer_version /etc/cgminer_version`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/cgminer_version"
        chmod 644 /etc/cgminer_version >/dev/null 2>&1
        cp -f /tmp/upgrade-files/rootfs/etc/cgminer_version /etc/
        chmod 444 /etc/cgminer_version # readonly
    fi
fi


# Confirm file attributes again
chmod 555 /usr/bin/cgminer
chmod 555 /usr/bin/cgminer-api
chmod 555 /usr/bin/cgminer-monitor
chmod 555 /usr/bin/miner-detect-common
chmod 555 /usr/bin/detect-miner-info
chmod 555 /usr/bin/lua-detect-version
chmod 555 /usr/bin/keyd
chmod 555 /usr/bin/readpower
chmod 555 /usr/bin/setpower
chmod 555 /usr/bin/system-monitor
chmod 555 /usr/bin/remote-daemon
chmod 555 /etc/init.d/boot
chmod 555 /etc/init.d/cgminer
chmod 555 /etc/init.d/detect-cgminer-config
chmod 555 /etc/init.d/remote-daemon
chmod 555 /etc/init.d/system-monitor
chmod 555 /etc/init.d/sdcard-upgrade
chmod 555 /bin/bitmicro-test
chmod 444 /etc/microbt_release
chmod 444 /etc/cgminer_version

echo "Done, reboot control board ..."

# reboot or sync may be blocked under some conditions
# so we call 'reboot -n -f' background to force rebooting
# after sleep timeout
sleep 20 && reboot -n -f &

sync
mount /dev/root -o remount,ro >/dev/null 2>&1
reboot

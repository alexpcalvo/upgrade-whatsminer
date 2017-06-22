#!/bin/sh

# Detect host (control board) type                                  
                                                                    
cpuinfo=`cat /proc/cpuinfo | grep "Xilinx Zynq Platform"`

if [ "$cpuinfo" != "" ]; then
	memsize=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`

    if [ $memsize -le 262144 ]; then
        control_board="CB12"
    else
        control_board="CB10"
    fi
else
    control_board="unknown"
fi

# Detect device (hash board) type

name0=`cat /sys/class/hwmon/hwmon0/name`
name1=`cat /sys/class/hwmon/hwmon1/name`
name2=`cat /sys/class/hwmon/hwmon2/name`

if [ "$name0" = "tmp421" -o "$name1" = "tmp421" -o "$name2" = "tmp421" ]; then
    hash_board="HB12"
else
    name0=`cat /sys/class/hwmon/hwmon0/name`
    name1=`cat /sys/class/hwmon/hwmon2/name`
    name2=`cat /sys/class/hwmon/hwmon4/name`

    if [ "$name0" = "tmp423" -o "$name1" = "tmp423" -o "$name2" = "tmp423" ]; then
        hash_board="HB10"
    elif [ "$name0" = "lm75" -o "$name1" = "lm75" -o "$name2" = "lm75" ]; then
        hash_board="ALB10"
    else
        hash_board="unknown"
    fi
fi

echo "Detected machine type: control_board=$control_board, hash_board=$hash_board"

if [ "$control_board" = "unknown" -o "$hash_board" = "unknown" ]; then
    echo "*********************************************************************"
    echo "Unknown machine type, quit the upgrade process."
    echo "*********************************************************************"
    exit 0
fi

#if [ "$control_board" != "CB12" -o "$hash_board" != "HB12" ]; then
#    echo "*********************************************************************"
#    echo "Detected: control_board=$control_board, hash_board=$hash_board."
#    echo "Machine type mismatched, quit the upgrade process."
#    echo "*********************************************************************"
#    exit 0
#fi

#
# Kill services
#
killall -9 crond >/dev/null 2>&1
killall -9 temp-monitor >/dev/null 2>&1
killall -9 keyd >/dev/null 2>&1
killall -9 cgminer >/dev/null 2>&1

#
# Verify and upgrade /tmp/upgrade-files/bin/*
#

# Detected files
if [ "$control_board" = "CB12" ]; then
    BOOTFILE="BOOT-ZYNQ12"
else
    BOOTFILE="BOOT-ZYNQ10"
fi

if [ "$hash_board" = "ALB10" ]; then
    CGMINERFILE="cgminer.alb10"
    CGMINERDEFAULTFILE="cgminer.default.alb10"
fi
if [ "$hash_board" = "HB12" ]; then
    CGMINERFILE="cgminer.hash12"
    CGMINERDEFAULTFILE="cgminer.default.hash12"
fi
if [ "$hash_board" = "HB10" ]; then
    CGMINERFILE="cgminer.hash10"
    CGMINERDEFAULTFILE="cgminer.default.hash10"
fi

# boot (mtd1)
if [ -f /tmp/upgrade-files/bin/$BOOTFILE.bin ]; then
    # verify with mtd data
    mtd verify /tmp/upgrade-files/bin/$BOOTFILE.bin /dev/mtd1 2>/tmp/.mtd-verify-stderr.txt
    result_success=`cat /tmp/.mtd-verify-stderr.txt | grep Success`
    if [ "$result_success" != "Success" ]; then
        # Require to upgrade.
        # First check the md5.
        md5v1=`md5sum /tmp/upgrade-files/bin/$BOOTFILE.bin | awk '{print $1}'`
        md5v2=`cat /tmp/upgrade-files/bin/$BOOTFILE.md5 | awk '{print $1}'`
        if [ "$md5v1" = "$md5v2" ]; then
            # upgrade to mtd
            echo "Upgrading $BOOTFILE.bin to /dev/mtd1"
            mtd erase /dev/mtd1
            mtd write /tmp/upgrade-files/bin/$BOOTFILE.bin /dev/mtd1
        fi
    fi
fi

# kernel (mtd4)
if [ -f /tmp/upgrade-files/bin/uImage ]; then
    # verify with mtd data
    mtd verify /tmp/upgrade-files/bin/uImage /dev/mtd4 2>/tmp/.mtd-verify-stderr.txt
    result_success=`cat /tmp/.mtd-verify-stderr.txt | grep Success`
    if [ "$result_success" != "Success" ]; then
        # Require to upgrade.
        # First check the md5.
        md5v1=`md5sum /tmp/upgrade-files/bin/uImage | awk '{print $1}'`
        md5v2=`cat /tmp/upgrade-files/bin/uImage.md5 | awk '{print $1}'`
        if [ "$md5v1" = "$md5v2" ]; then
            # upgrade to mtd
            echo "Upgrading kernel.bin to /dev/mtd4"
            mtd erase /dev/mtd4
            mtd write /tmp/upgrade-files/bin/uImage /dev/mtd4
        fi
    fi
fi

# devicetree (mtd5)
if [ -f /tmp/upgrade-files/bin/devicetree.dtb ]; then
    # verify with mtd data
    mtd verify /tmp/upgrade-files/bin/devicetree.dtb /dev/mtd5 2>/tmp/.mtd-verify-stderr.txt
    result_success=`cat /tmp/.mtd-verify-stderr.txt | grep Success`
    if [ "$result_success" != "Success" ]; then
        # Require to upgrade.
        # First check the md5.
        md5v1=`md5sum /tmp/upgrade-files/bin/devicetree.dtb | awk '{print $1}'`
        md5v2=`cat /tmp/upgrade-files/bin/devicetree.md5 | awk '{print $1}'`
        if [ "$md5v1" = "$md5v2" ]; then
            # upgrade to mtd
            echo "Upgrading devicetree.bin to /dev/mtd5"
            mtd erase /dev/mtd5
            mtd write /tmp/upgrade-files/bin/devicetree.dtb /dev/mtd5
        fi
    fi
fi

#
# Verify and upgrade /tmp/upgrade-files/rootfs/*
#
echo ""
echo "Upgrading rootfs"

# /etc/microbt_release
if [ -f /tmp/upgrade-files/rootfs/etc/microbt_release ]; then
    echo "Upgrading /etc/microbt_release"
    chmod 644 /etc/microbt_release
    cp -f /tmp/upgrade-files/rootfs/etc/microbt_release /etc/
    chmod 444 /etc/microbt_release # readonly
fi
# /etc/cgminer_version
if [ -f /tmp/upgrade-files/rootfs/etc/cgminer_version ]; then
    echo "Upgrading /etc/cgminer_version"
    chmod 644 /etc/cgminer_version
    cp -f /tmp/upgrade-files/rootfs/etc/cgminer_version /etc/
    chmod 444 /etc/cgminer_version # readonly
fi

# /etc/config/network.default
if [ -f /tmp/upgrade-files/rootfs/etc/config/network.default ]; then
    echo "Upgrading /etc/config/network.default"
    chmod 644 /etc/config/network.default
    cp -f /tmp/upgrade-files/rootfs/etc/config/network.default /etc/config/network.default
    chmod 444 /etc/config/network.default # readonly
fi

# /etc/config/pools.default
if [ -f /tmp/upgrade-files/rootfs/etc/config/pools.default ]; then
    echo "Upgrading /etc/config/pools.default"
    chmod 644 /etc/config/pools.default >/dev/null 2>&1
    cp -f /tmp/upgrade-files/rootfs/etc/config/pools.default /etc/config/pools.default
    chmod 444 /etc/config/pools.default # readonly
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

# /etc/config/cgminer
if [ -f /tmp/upgrade-files/rootfs/etc/config/$CGMINERFILE ]; then
    echo "Upgrading from $CGMINERFILE to /etc/config/cgminer"
    chmod 644 /etc/config/cgminer
    cp -f /tmp/upgrade-files/rootfs/etc/config/$CGMINERFILE /etc/config/cgminer
    chmod 444 /etc/config/cgminer # readonly
fi
# /etc/config/cgminer.default
if [ -f /tmp/upgrade-files/rootfs/etc/config/$CGMINERDEFAULTFILE ]; then
    echo "Upgrading from $CGMINERDEFAULTFILE to /etc/config/cgminer.default"
    chmod 644 /etc/config/cgminer.default
    cp -f /tmp/upgrade-files/rootfs/etc/config/$CGMINERDEFAULTFILE /etc/config/cgminer.default
    chmod 444 /etc/config/cgminer.default # readonly
fi

# /etc/init.d/boot
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/boot ]; then
    echo "Upgrading /etc/init.d/boot"
    cp -f /tmp/upgrade-files/rootfs/etc/init.d/boot /etc/init.d/boot
    chmod 755 /etc/init.d/boot
fi

# /etc/crontabs/root
if [ -f /tmp/upgrade-files/rootfs/etc/crontabs/root ]; then
    echo "Upgrading /etc/crontabs/root"
    cp -f /tmp/upgrade-files/rootfs/etc/crontabs/root /etc/crontabs/
fi

# /etc/init.d/cgminer
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/cgminer ]; then
    echo "Upgrading /etc/init.d/cgminer"
    cp -f /tmp/upgrade-files/rootfs/etc/init.d/cgminer /etc/init.d/cgminer
    chmod 755 /etc/init.d/cgminer
fi

# /etc/init.d/temp-monitor
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/temp-monitor ]; then
    echo "Upgrading /etc/init.d/temp-monitor"
    cp -f /tmp/upgrade-files/rootfs/etc/init.d/temp-monitor /etc/init.d/temp-monitor
    chmod 755 /etc/init.d/temp-monitor
    cd /etc/rc.d/
    ln -s ../init.d/temp-monitor S90temp-monitor >/dev/null 2>&1
    cd -
fi

# /etc/init.d/sdcard-upgrade
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/sdcard-upgrade ]; then
    echo "Upgrading /etc/init.d/sdcard-upgrade"
    cp -f /tmp/upgrade-files/rootfs/etc/init.d/sdcard-upgrade /etc/init.d/sdcard-upgrade
    chmod 755 /etc/init.d/sdcard-upgrade
    cd /etc/rc.d/
    ln -s ../init.d/sdcard-upgrade S97sdcard-upgrade >/dev/null 2>&1
    cd -
fi

# Remove unused files under /etc
rm -f /etc/config/firewall
rm -f /etc/init.d/om-watchdog
rm -f /etc/rc.d/S11om-watchdog
rm -f /etc/rc.d/K11om-watchdog

# /usr/bin/cgminer
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer ]; then
    echo "Upgrading /usr/bin/cgminer"
    cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer /usr/bin/
    chmod 755 /usr/bin/cgminer
fi

# /usr/bin/cgminer-api
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-api ]; then
    echo "Upgrading /usr/bin/cgminer-api"
    cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-api /usr/bin/
    chmod 755 /usr/bin/cgminer-api
fi

# /usr/bin/cgminer-monitor
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-monitor ]; then
    echo "Upgrading /usr/bin/cgminer-monitor"
    cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-monitor /usr/bin/
    chmod 755 /usr/bin/cgminer-monitor
fi

# /usr/bin/temp-monitor
if [ -f /tmp/upgrade-files/rootfs/usr/bin/temp-monitor ]; then
    echo "Upgrading /usr/bin/temp-monitor"
    cp -f /tmp/upgrade-files/rootfs/usr/bin/temp-monitor /usr/bin/
    chmod 755 /usr/bin/temp-monitor
fi

# /usr/bin/setpower
if [ -f /tmp/upgrade-files/rootfs/usr/bin/setpower ]; then
    echo "Upgrading /usr/bin/setpower"
    cp -f /tmp/upgrade-files/rootfs/usr/bin/setpower /usr/bin/
    chmod 755 /usr/bin/setpower
fi

# /usr/bin/readpower
if [ -f /tmp/upgrade-files/rootfs/usr/bin/readpower ]; then
    echo "Upgrading /usr/bin/readpower"
    cp -f /tmp/upgrade-files/rootfs/usr/bin/readpower /usr/bin/
    chmod 755 /usr/bin/readpower
fi

# /usr/bin/keyd
if [ -f /tmp/upgrade-files/rootfs/usr/bin/keyd ]; then
    echo "Upgrading /usr/bin/keyd"
    cp -f /tmp/upgrade-files/rootfs/usr/bin/keyd /usr/bin/
    chmod 755 /usr/bin/keyd
fi

# /usr/lib/lua
if [ -d /tmp/upgrade-files/rootfs/usr/lib/lua ]; then
    echo "Upgrading /usr/lib/lua"
    rm -fr /usr/lib/lua
    cp -afr /tmp/upgrade-files/rootfs/usr/lib/lua /usr/lib/
fi

# /bin/bitmicro-test, test-readchipid, test-sendgoldenwork, test-hashboard
if [ -f /tmp/upgrade-files/rootfs/bin/bitmicro-test ]; then
    echo "Upgrading /bin/bitmicro-test"
    rm -f /bin/bitmicrotest
    cp -f /tmp/upgrade-files/rootfs/bin/bitmicro-test /bin/
    chmod 755 /bin/bitmicro-test
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-readchipid ]; then
    echo "Upgrading /bin/test-readchipid"
    cp -f /tmp/upgrade-files/rootfs/bin/test-readchipid /bin/
    chmod 755 /bin/test-readchipid
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-sendgoldenwork ]; then
    echo "Upgrading /bin/test-sendgoldenwork"
    cp -f /tmp/upgrade-files/rootfs/bin/test-sendgoldenwork /bin/
    chmod 755 /bin/test-sendgoldenwork
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-hashboard ]; then
    echo "Upgrading /bin/test-hashboard"
    cp -f /tmp/upgrade-files/rootfs/bin/test-hashboard /bin/
    chmod 755 /bin/test-hashboard
fi

# sensors and relative libs
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

echo ""
echo "Done, reboot system ..."
sync
reboot

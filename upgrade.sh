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

if [ "$isH3Platform" = true ]; then
    hwmon0_path="/sys/class/hwmon/hwmon1/device/"
    hwmon1_path="/sys/class/hwmon/hwmon2/device/"
    hwmon2_path="/sys/class/hwmon/hwmon3/device/"
    hwmon4_path="/sys/class/hwmon/hwmon5/device/"
else
    hwmon0_path="/sys/class/hwmon/hwmon0/"
    hwmon1_path="/sys/class/hwmon/hwmon1/"
    hwmon2_path="/sys/class/hwmon/hwmon2/"
    hwmon4_path="/sys/class/hwmon/hwmon4/"
fi

# Detect hash board type
if [ -f $hwmon0_path/name ]; then
    name0=`cat $hwmon0_path/name`
fi
if [ -f $hwmon1_path/name ]; then
    name1=`cat $hwmon1_path/name`
fi
if [ -f $hwmon2_path/name ]; then
    name2=`cat $hwmon2_path/name`
fi

if [ "$name0" = "tmp421" -o "$name1" = "tmp421" -o "$name2" = "tmp421" ]; then
    hash_board="HB12"
elif [ "$name0" = "lm75" -o "$name1" = "lm75" -o "$name2" = "lm75" ]; then
    hash_board="ALB10"
else
    if [ -f $hwmon0_path/name ]; then
        name0=`cat $hwmon0_path/name`
    fi
    if [ -f $hwmon2_path/name ]; then
        name1=`cat $hwmon2_path/name`
    fi
    if [ -f $hwmon4_path/name ]; then
        name2=`cat $hwmon4_path/name`
    fi

    if [ "$name0" = "tmp423" -o "$name1" = "tmp423" -o "$name2" = "tmp423" ]; then
        hash_board="HB10"
    else
        hash_board="unknown"
    fi
fi

echo "Detected machine type: control_board=$control_board, hash_board=$hash_board"

if [ "$control_board" = "unknown" ]; then
    echo "*********************************************************************"
    echo "Unknown control board, quit the upgrade process."
    echo "*********************************************************************"
    exit 0
fi

if [ "$hash_board" = "unknown" ]; then
    echo "Unknown hash board, assume hash_board=ALB10."
    hash_board="ALB10"
fi

# Compare two files.
# Return 'no' if these two files are the same,
# else return 'yes'.
diff_files() {
    if [ ! -f $1 -o ! -f $2 ]; then
        echo "yes"
    else
        DIFF=`cmp $1 $2 2>/dev/null`
        if [ "$DIFF" = "" ]; then
            echo "no"
        else
            echo "yes"
        fi
    fi
}

#
# Prepare rootfs
#
if [ "$isH3Platform" = true ]; then
    # H3: 1) remove useless files; 2) replace xxx with xxx.h3
    rm -f `ls /tmp/upgrade-files/bin/* | grep -v boot.fex`
    rm -f /tmp/upgrade-files/packages/*

    for file in $(find /tmp/upgrade-files/rootfs -name *.h3)
    do
        newfile=`echo $file | sed 's/\.h3$//'`
        mv $file $newfile
    done
else
    # ZYNQ: 1) remove useless files for h3
    rm -f /tmp/upgrade-files/bin/boot.fex
    find /tmp/upgrade-files/rootfs -name *.h3 | xargs rm -f
fi

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
if [ "$control_board" = "ZYNQ-CB12" ]; then
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

# kernel (mtd4 for ZYNQ)
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

# kernel (nandc for H3)
if [ -f /tmp/upgrade-files/bin/boot.fex ]; then
    echo "Upgrading boot.fex to /dev/nandc"
    cat /tmp/upgrade-files/bin/boot.fex > /dev/nandc
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

# /etc/microbt_release
if [ -f /tmp/upgrade-files/rootfs/etc/microbt_release ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/microbt_release /etc/microbt_release`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/microbt_release"
        chmod 644 /etc/microbt_release
        cp -f /tmp/upgrade-files/rootfs/etc/microbt_release /etc/
        chmod 444 /etc/microbt_release # readonly
    fi
fi
# /etc/cgminer_version
if [ -f /tmp/upgrade-files/rootfs/etc/cgminer_version ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/cgminer_version /etc/cgminer_version`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/cgminer_version"
        chmod 644 /etc/cgminer_version
        cp -f /tmp/upgrade-files/rootfs/etc/cgminer_version /etc/
        chmod 444 /etc/cgminer_version # readonly
    fi
fi

# /etc/config/system
if [ -f /tmp/upgrade-files/rootfs/etc/config/system ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/system /etc/config/system`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/system"
        chmod 644 /etc/config/system
        cp -f /tmp/upgrade-files/rootfs/etc/config/system /etc/config/system
        chmod 444 /etc/config/system # readonly
    fi
fi

# /etc/config/network.default
if [ -f /tmp/upgrade-files/rootfs/etc/config/network.default ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/network.default /etc/config/network.default`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/config/network.default"
        chmod 644 /etc/config/network.default
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

# /etc/config/cgminer.alb10
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.alb10 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.alb10 /etc/config/cgminer.alb10`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.alb10 to /etc/config/cgminer.alb10"
        chmod 644 /etc/config/cgminer.alb10
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.alb10 /etc/config/cgminer.alb10
        chmod 444 /etc/config/cgminer.alb10 # readonly
    fi
fi
# /etc/config/cgminer.default.alb10
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.alb10 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.alb10 /etc/config/cgminer.default.alb10`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.alb10 to /etc/config/cgminer.default.alb10"
        chmod 644 /etc/config/cgminer.default.alb10
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.alb10 /etc/config/cgminer.default.alb10
        chmod 444 /etc/config/cgminer.default.alb10 # readonly
    fi
fi

# /etc/config/cgminer.hash12
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.hash12 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.hash12 /etc/config/cgminer.hash12`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.hash12 to /etc/config/cgminer.hash12"
        chmod 644 /etc/config/cgminer.hash12
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.hash12 /etc/config/cgminer.hash12
        chmod 444 /etc/config/cgminer.hash12 # readonly
    fi
fi
# /etc/config/cgminer.default.hash12
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.hash12 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.hash12 /etc/config/cgminer.default.hash12`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.hash12 to /etc/config/cgminer.default.hash12"
        chmod 644 /etc/config/cgminer.default.hash12
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.hash12 /etc/config/cgminer.default.hash12
        chmod 444 /etc/config/cgminer.default.hash12 # readonly
    fi
fi

# /etc/config/cgminer.hash10
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.hash10 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.hash10 /etc/config/cgminer.hash10`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.hash10 to /etc/config/cgminer.hash10"
        chmod 644 /etc/config/cgminer.hash10
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.hash10 /etc/config/cgminer.hash10
        chmod 444 /etc/config/cgminer.hash10 # readonly
    fi
fi
# /etc/config/cgminer.default.hash10
if [ -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.hash10 ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/cgminer.default.hash10 /etc/config/cgminer.default.hash10`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading cgminer.default.hash10 to /etc/config/cgminer.default.hash10"
        chmod 644 /etc/config/cgminer.default.hash10
        cp -f /tmp/upgrade-files/rootfs/etc/config/cgminer.default.hash10 /etc/config/cgminer.default.hash10
        chmod 444 /etc/config/cgminer.default.hash10 # readonly
    fi
fi

# Link /etc/config/cgminer
if [ -f /tmp/upgrade-files/rootfs/etc/config/$CGMINERFILE ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/$CGMINERFILE /etc/config/cgminer`
    if [ "$DIFF" = "yes" ]; then
        echo "Link $CGMINERFILE to /etc/config/cgminer"
        cd /etc/config/
        chmod 644 cgminer
        rm -f cgminer
        ln -s $CGMINERFILE cgminer
        chmod 444 cgminer # readonly
        cd - >/dev/null
    fi
fi
# Link /etc/config/cgminer.default
if [ -f /tmp/upgrade-files/rootfs/etc/config/$CGMINERDEFAULTFILE ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/config/$CGMINERDEFAULTFILE /etc/config/cgminer.default`
    if [ "$DIFF" = "yes" ]; then
        echo "Link $CGMINERDEFAULTFILE to /etc/config/cgminer.default"
        cd /etc/config/
        chmod 644 cgminer.default
        rm -f cgminer.default
        ln -s $CGMINERDEFAULTFILE cgminer.default
        chmod 444 cgminer.default # readonly
        cd - >/dev/null
    fi
fi

# /etc/init.d/boot
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/boot ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/boot /etc/init.d/boot`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/boot"
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/boot /etc/init.d/boot
        chmod 755 /etc/init.d/boot
    fi
fi

# /etc/init.d/detect-cgminer-config
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/detect-cgminer-config ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/detect-cgminer-config /etc/init.d/detect-cgminer-config`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/detect-cgminer-config"
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/detect-cgminer-config /etc/init.d/detect-cgminer-config
        chmod 755 /etc/init.d/detect-cgminer-config
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
        cp -f /tmp/upgrade-files/rootfs/etc/crontabs/root /etc/crontabs/
    fi
fi

# /etc/init.d/cgminer
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/cgminer ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/cgminer /etc/init.d/cgminer`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/cgminer"
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/cgminer /etc/init.d/cgminer
        chmod 755 /etc/init.d/cgminer
    fi
fi

# /etc/init.d/temp-monitor
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/temp-monitor ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/temp-monitor /etc/init.d/temp-monitor`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/temp-monitor"
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/temp-monitor /etc/init.d/temp-monitor
        chmod 755 /etc/init.d/temp-monitor
        cd /etc/rc.d/
        ln -s ../init.d/temp-monitor S90temp-monitor >/dev/null 2>&1
        cd - >/dev/null
    fi
fi

# /etc/init.d/sdcard-upgrade
if [ -f /tmp/upgrade-files/rootfs/etc/init.d/sdcard-upgrade ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/etc/init.d/sdcard-upgrade /etc/init.d/sdcard-upgrade`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /etc/init.d/sdcard-upgrade"
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/sdcard-upgrade /etc/init.d/sdcard-upgrade
        chmod 755 /etc/init.d/sdcard-upgrade
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
        cp -f /tmp/upgrade-files/rootfs/etc/init.d/remote-daemon /etc/init.d/remote-daemon
        chmod 755 /etc/init.d/remote-daemon
        cd /etc/rc.d/
        ln -s ../init.d/remote-daemon S90remote-daemon >/dev/null 2>&1
        cd - >/dev/null
    fi
fi

# Remove unused files under /etc
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

# /usr/bin/cgminer
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/cgminer /usr/bin/cgminer`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/cgminer"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer /usr/bin/cgminer
        chmod 755 /usr/bin/cgminer
    fi
fi

# /usr/bin/cgminer-api
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-api ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/cgminer-api /usr/bin/cgminer-api`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/cgminer-api"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-api /usr/bin/cgminer-api
        chmod 755 /usr/bin/cgminer-api
    fi
fi

# /usr/bin/cgminer-monitor
if [ -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-monitor ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/cgminer-monitor /usr/bin/cgminer-monitor`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/cgminer-monitor"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/cgminer-monitor /usr/bin/cgminer-monitor
        chmod 755 /usr/bin/cgminer-monitor
    fi
fi

# /usr/bin/temp-monitor
if [ -f /tmp/upgrade-files/rootfs/usr/bin/temp-monitor ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/temp-monitor /usr/bin/temp-monitor`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/temp-monitor"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/temp-monitor /usr/bin/temp-monitor
        chmod 755 /usr/bin/temp-monitor
    fi
fi

# /usr/bin/setpower
if [ -f /tmp/upgrade-files/rootfs/usr/bin/setpower ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/setpower /usr/bin/setpower`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/setpower"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/setpower /usr/bin/setpower
        chmod 755 /usr/bin/setpower
    fi
fi

# /usr/bin/readpower
if [ -f /tmp/upgrade-files/rootfs/usr/bin/readpower ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/readpower /usr/bin/readpower`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/readpower"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/readpower /usr/bin/readpower
        chmod 755 /usr/bin/readpower
    fi
fi

# /usr/bin/keyd
if [ -f /tmp/upgrade-files/rootfs/usr/bin/keyd ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/keyd /usr/bin/keyd`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/keyd"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/keyd /usr/bin/keyd
        chmod 755 /usr/bin/keyd
    fi
fi

# /usr/bin/remote-daemon
if [ -f /tmp/upgrade-files/rootfs/usr/bin/remote-daemon ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/remote-daemon /usr/bin/remote-daemon`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/remote-daemon"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/remote-daemon /usr/bin/remote-daemon
        chmod 755 /usr/bin/remote-daemon
    fi
fi

# /usr/bin/detect-miner-info
if [ -f /tmp/upgrade-files/rootfs/usr/bin/detect-miner-info ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/usr/bin/detect-miner-info /usr/bin/detect-miner-info`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /usr/bin/detect-miner-info"
        cp -f /tmp/upgrade-files/rootfs/usr/bin/detect-miner-info /usr/bin/detect-miner-info
        chmod 755 /usr/bin/detect-miner-info
    fi
fi

# /usr/lib/lua
if [ -d /tmp/upgrade-files/rootfs/usr/lib/lua ]; then
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
fi

# /bin/bitmicro-test, test-readchipid, test-sendgoldenwork, test-hashboard
if [ -f /tmp/upgrade-files/rootfs/bin/bitmicro-test ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/bin/bitmicro-test /bin/bitmicro-test`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /bin/bitmicro-test"
        rm -f /bin/bitmicrotest
        cp -f /tmp/upgrade-files/rootfs/bin/bitmicro-test /bin/bitmicro-test
        chmod 755 /bin/bitmicro-test
    fi
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-readchipid ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/bin/test-readchipid /bin/test-readchipid`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /bin/test-readchipid"
        cp -f /tmp/upgrade-files/rootfs/bin/test-readchipid /bin/test-readchipid
        chmod 755 /bin/test-readchipid
    fi
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-sendgoldenwork ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/bin/test-sendgoldenwork /bin/test-sendgoldenwork`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /bin/test-sendgoldenwork"
        cp -f /tmp/upgrade-files/rootfs/bin/test-sendgoldenwork /bin/test-sendgoldenwork
        chmod 755 /bin/test-sendgoldenwork
    fi
fi
if [ -f /tmp/upgrade-files/rootfs/bin/test-hashboard ]; then
    DIFF=`diff_files /tmp/upgrade-files/rootfs/bin/test-hashboard /bin/test-hashboard`
    if [ "$DIFF" = "yes" ]; then
        echo "Upgrading /bin/test-hashboard"
        cp -f /tmp/upgrade-files/rootfs/bin/test-hashboard /bin/test-hashboard
        chmod 755 /bin/test-hashboard
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

# Sync to flash
sync

echo ""
echo "Done, reboot control board ..."
reboot

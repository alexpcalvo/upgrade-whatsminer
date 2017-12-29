#!/bin/sh
#
# Update upgrade-rootfs/* from upgrade-files/*
#

upgrade_files_tmp_dir=/tmp/upgrade-files-tmp

#
# 1. Update upgrade-rootfs/zynq-rootfs/
#
rm -fr $upgrade_files_tmp_dir
mkdir -p $upgrade_files_tmp_dir
cp -af upgrade-files/rootfs $upgrade_files_tmp_dir

# Remove useless files
find $upgrade_files_tmp_dir/rootfs -name "*.h3" | xargs rm -f
rm -f $upgrade_files_tmp_dir/rootfs/etc/rc.d/S90phonixtest
rm -f $upgrade_files_tmp_dir/rootfs/etc/init.d/phonixtest
rm -f $upgrade_files_tmp_dir/rootfs/usr/bin/phonixtest
rm -f $upgrade_files_tmp_dir/rootfs/etc/rc.local
rm -fr upgrade-rootfs/zynq-rootfs/usr/lib/lua

# Copy ...
cp -af $upgrade_files_tmp_dir/rootfs/* upgrade-rootfs/zynq-rootfs/

# These files will not be upgraded
rm -f upgrade-rootfs/zynq-rootfs/etc/config/pools
rm -f upgrade-rootfs/zynq-rootfs/etc/config/network
rm -f upgrade-rootfs/zynq-rootfs/etc/shadow
rm -f upgrade-rootfs/zynq-rootfs/etc/shadow-

#
# 2. Update upgrade-rootfs/h3-rootfs/
#
rm -fr $upgrade_files_tmp_dir
mkdir -p $upgrade_files_tmp_dir
cp -af upgrade-files/rootfs $upgrade_files_tmp_dir

# Remove useless files
for file in $(find $upgrade_files_tmp_dir/rootfs -name "*.h3")
do
    newfile=`echo $file | sed 's/\.h3$//'`
    mv $file $newfile
done
rm -fr upgrade-rootfs/h3-rootfs/usr/lib/lua

# Copy ...
cp -af $upgrade_files_tmp_dir/rootfs/* upgrade-rootfs/h3-rootfs/

# These files will not be upgraded
rm -f upgrade-rootfs/h3-rootfs/etc/config/pools
rm -f upgrade-rootfs/h3-rootfs/etc/config/network
rm -f upgrade-rootfs/h3-rootfs/etc/shadow
rm -f upgrade-rootfs/h3-rootfs/etc/shadow-
rm -f upgrade-rootfs/h3-rootfs/etc/boot.md5

# Delete tmp dir
rm -fr $upgrade_files_tmp_dir

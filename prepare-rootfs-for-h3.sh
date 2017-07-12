#!/bin/sh

if [ $# != 1 ]; then
	echo "Usage: $0 <tmp-rootfs>"
	exit 0
fi

echo "$0 $1"

tmp_src_dir=$1

if [ ! -d $tmp_src_dir ]; then
	echo "No such dir $tmp_src_dir"
	exit 0
fi

find $tmp_src_dir/ -name *.h3 | xargs rename -f 's/\.h3$//'

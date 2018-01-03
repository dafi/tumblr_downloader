#!/bin/bash
. config.sh

for i in $( egrep -e "-- : (\d{7,}).*" images.log | awk '{print $7}' | sort -u ) ; do
	res=`find $IMAGE_DIR -name $i.jpg`
	if [ -z "$res" ]; then
		echo "$i not found"
	fi
done

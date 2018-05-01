# Create simbolic links to matching file to simplify browsing from viewers

#!/bin/bash
. ../config.sh

ROOT_DIR=$IMAGE_DIR
MATCHING_DIR=matching
RESULTS_DIR=results

function mk_syms {
	mkdir -p $MATCHING_DIR/$1

	grep --null -Rl "$2" results/$1 | while IFS= read -r -d '' file; do
	    REL_PATH=`head -1 "$file" | sed 's/image: //'`
	    DIR_NAME=`dirname "$REL_PATH"`
	    FILE_NAME=`basename "$REL_PATH"`
	    ln -s "$ROOT_DIR/$REL_PATH" $MATCHING_DIR/$1/$FILE_NAME
	done
}

mk_syms c "$1"
mk_syms d "$1"

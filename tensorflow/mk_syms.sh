# Create simbolic links to matching file to simplify browsing from viewers

#!/bin/bash
. ../config.sh

ROOT_DIR=$IMAGE_DIR
MATCHING_DIR=matching/c

mkdir -p $MATCHING_DIR

grep --null -Rl "$1" results | while IFS= read -r -d '' file; do
    REL_PATH=`head -1 "$file" | sed 's/image: //'`
    DIR_NAME=`dirname "$REL_PATH"`
    FILE_NAME=`basename "$REL_PATH"`
    # echo mkdir $MATCHING_DIR/$DIR_NAME
    ln -s "$ROOT_DIR/$REL_PATH" $MATCHING_DIR/$FILE_NAME
done
#!/bin/bash
# Create simbolic links to matching file, this helps file browsing with image viewers

. ../config.sh

ROOT_DIR=$IMAGE_DIR
MATCHING_DIR=matching
RESULTS_DIR=results

function mk_syms {
	DEST_DIR="$MATCHING_DIR/$1"
	mkdir -p $DEST_DIR

	grep --null -Rl "$2" "$RESULTS_DIR/$1" | while IFS= read -r -d '' file; do
	    REL_PATH=`head -1 "$file" | sed 's/image: //'`
	    DIR_NAME=`dirname "$REL_PATH"`
	    FILE_NAME=`basename "$REL_PATH"`
	    ln -s "$ROOT_DIR/$REL_PATH" "$DEST_DIR/$FILE_NAME"
	done
}

function show_help() {
	echo "-i <input_path> the path containing the classificated files with Tensorflow (relative to '$RESULTS_DIR')"
	echo "-p pattern to use to filter files (eg. score score [1-2]:.*panda"
}

input_path=""
pattern=""

while getopts "h?i:p:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    i)  input_path=$OPTARG
        ;;
    p)  pattern=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

[ $OPTIND = 1 ] && show_help && exit 0

[ -z "$input_path" ] && echo "Input path is mandatory" && exit 1
[ -z "$pattern" ] && echo "Pattern is mandatory" && exit 1

mk_syms "$input_path" "$pattern"


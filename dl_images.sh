#!/bin/bash
. config.sh

./image_downloader.rb -j "blogs/$BLOG_NAME.tumblr.com" -o "$IMAGE_DIR"


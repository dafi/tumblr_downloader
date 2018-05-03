#!/bin/bash
# Open all urls by postId, the postId list is contained into the file postIdList.txt

. ../config.sh

while IFS='' read -r line || [[ -n "$line" ]]; do
    open http://$BLOG_NAME.tumblr.com/post/$line
done < "../temp/postIdList.txt"

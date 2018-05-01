# remove from the array tags all strings present in names.txt and bad_tags.txt
DEST_DIR = 'tags'.freeze

names = open(File.join(DEST_DIR, 'names.txt')).read.split("\n")
tags = open(File.join(DEST_DIR, 'tags.txt')).read.split("\n")
bad_tags = open(File.join(DEST_DIR, 'bad_tags.txt')).read.split("\n")

names += bad_tags

tags.reject! do |tag|
  names.index { |name| tag.start_with?(name) }
end

puts tags

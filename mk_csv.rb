#!/usr/bin/env ruby
# Print CSV content as expected by PhotoShelf
require 'json'

def print_csv_lines(posts)
  posts.each do |post|
    blog_name = post['blog_name']
    post_id = post['id']
    timestamp = post['timestamp']
    tags = post['tags']

    tags.each_with_index do |t, idx|
      puts "#{post_id};#{blog_name};#{t.downcase};#{timestamp};#{idx + 1}"
    end
  end
end

def parse_file(path)
  json_map = JSON.parse(open(path).read)
  response = json_map['response']
  response['posts']
end

if ARGV.empty?
  puts 'Specify the directory containing JSON files'
  exit
end

def read_files(dir)
  posts = []
  Dir.glob(File.join(dir, '*.json')) do |f|
    posts += parse_file(f)
  end
  posts.sort! { |a, b| a['id'].to_i <=> b['id'].to_i }
  print_csv_lines(posts)
end

read_files(ARGV[0])

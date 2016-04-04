# Print CSV content as expected by PhotoShelf
require 'json'

def print_csv_lines(posts)
  posts.each do |post|
    blog_name = post['blog_name']
    post_id = post['id']
    timestamp = post['timestamp']
    tags = post['tags']

    tags.each_with_index do |t, idx|
      puts "#{post_id};#{blog_name};#{t};#{timestamp};#{idx + 1}"
    end
  end
end

def parse_file(path)
  json_map = JSON.parse(open(path).read)
  response = json_map['response']
  posts = response['posts']
  print_csv_lines posts
end

if ARGV.empty?
  puts 'Specify the directory containing JSON files'
  exit
end

Dir.glob(File.join(ARGV[0], '*.json')) do |f|
  parse_file f if File.file?(f)
end

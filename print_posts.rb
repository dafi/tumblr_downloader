#!/usr/bin/env ruby
require 'set'
require 'json'
require 'optparse'

# Print different posts fields content
class PostPrinter
  def print_csv(posts)
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

  def tags(posts)
    all_tags = Set.new

    posts.each do |post|
      all_tags.merge(post['tags'].map(&:downcase))
    end
    all_tags.to_a.sort
  end

  def print_tags(posts)
    puts(tags(posts))
  end

  def print_html_tags(posts)
    tags(posts).each do |tag|
      tag_underscore = tag.gsub(/\s/, '_')
      puts "<a href=\"#{@blog_url}tagged/#{tag_underscore}\">#{tag}</a><br/>"
    end
  end

  def parse_file(path)
    json_map = JSON.parse(open(path).read)
    json_map['response']
  end

  def read_files(dir)
    posts = []
    Dir.glob(File.join(dir, '*.json')) do |f|
      response = parse_file(f)
      @blog_url = response['blog']['url'] if @blog_url.nil?
      posts += response['posts']
    end
    posts.sort! { |a, b| a['id'].to_i <=> b['id'].to_i }
    # duplicates are possibile when the posts are updated
    # starting from the current max id value
    posts.uniq! { |p| p['id'] }
  end

  def self.parse_command_line
    cmd_opts = OpenStruct.new
    cmd_opts.print_csv = false
    cmd_opts.print_tags = false
    cmd_opts.print_html_tags = false
    cmd_opts.posts_path = nil

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

      opts.on('-p', '--post-path path', 'The path containing posts JSON files') do |posts_path|
        cmd_opts.posts_path = posts_path
      end
      opts.on('-c', '--csv', 'Print CSV as expected by PhotoShelf') do |flag|
        cmd_opts.print_csv = flag
      end
      opts.on('-t', '--tags', 'Print tags') do |flag|
        cmd_opts.print_tags = flag
      end
      opts.on('', '--html', 'Print HTML tags list') do |flag|
        cmd_opts.print_html_tags = flag
      end

      opts.separator ''
      opts.on_tail('-h', '--help', 'This help text') do
        puts opts
        exit
      end
    end

    begin
      optparse.parse!
      mandatory = [:posts_path]
      missing = mandatory.select { |param| cmd_opts[param].nil? }
      unless missing.empty?
        puts "Missing options: #{missing.join(', ')}"
        puts optparse
        exit
      end
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument
        puts $!.to_s
        puts optparse
        exit
    end

    if !cmd_opts.print_tags && !cmd_opts.print_csv && !cmd_opts.print_html_tags
      puts 'Nothing to print, specify at least a printer'
      puts optparse
      exit
    end

    # puts "Performing task with options: #{cmd_opts.inspect}"

    cmd_opts
  end
end

opts = PostPrinter.parse_command_line
po = PostPrinter.new
posts = po.read_files(opts.posts_path)
po.print_tags(posts) if opts.print_tags
po.print_csv(posts) if opts.print_csv
po.print_html_tags(posts) if opts.print_html_tags

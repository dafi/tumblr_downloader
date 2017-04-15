#!/usr/bin/env ruby

require 'open-uri'
require 'uri'
require 'json'
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'set'

# Download all tumblr public posts
# The posts (as JSON) are saved on local directory to speedup reload
class TumblrDownloader
  def initialize(opts)
    @opts = opts

    @blog_url = TumblrDownloader.fix_url_domain(@opts.blog_url)
    @cache_dir = if @opts.prefix_cache_dir
                   File.join(@opts.prefix_cache_dir, @blog_url)
                 else
                   @blog_url
                 end
    FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
  end

  def read_json_write_cache(url)
    text = open(url).read

    # file name is the current time in milliseconds
    dest_file_name = (Time.now.to_f * 1000).to_i
    # when reading from real url we must write to cache
    unless @opts.use_cache
      open(File.join(@cache_dir, "#{dest_file_name}.json"), 'wb') do |file|
        file << text
      end
    end

    OpenStruct.new(JSON.parse(text))
  end

  def mk_url(url, offset)
    return File.join(@cache_dir, "#{offset}.json") if @opts.use_cache
    "#{url}&offset=#{offset}"
  end

  def self.fix_url_domain(url)
    return url if url.include? '.'
    url + '.tumblr.com'
  end

  # return the array where every index contains the read posts at that (tumblr) offset
  def download
    url = "https://api.tumblr.com/v2/blog/#{@blog_url}/posts/photo?api_key=#{@opts.api_key}"

    offset = 0
    curr_max_id = find_max_id_from_cache
    posts = read_json_write_cache(mk_url(url, offset))
    total_posts = @opts.max_posts ? @opts.max_posts.to_i : posts['response']['blog']['posts']

    while offset < total_posts && contain_newer_post?(curr_max_id, posts)
      puts "#{offset}/#{total_posts}"
      post_count = posts['response']['posts'].count

      break if post_count.zero?
      offset += post_count

      posts = read_json_write_cache(mk_url(url, offset))
    end
  end

  def contain_newer_post?(curr_max_id, posts)
    return true if curr_max_id <= 0
    find_max_id(posts, curr_max_id) > curr_max_id
  end

  def find_max_id_from_cache
    max_id = 0
    Dir[File.join(@cache_dir, '*.json')].each do |f|
      posts = OpenStruct.new(JSON.parse(open(f).read))
      max_id = find_max_id(posts, max_id)
    end
    max_id
  end

  def find_max_id(posts, curr_max)
    posts['response']['posts'].each do |post|
      curr_max = post['id'] if post['id'] > curr_max
    end
    curr_max
  end

  def self.parse_command_line
    cmd_opts = OpenStruct.new
    cmd_opts.blog_url = nil
    cmd_opts.api_key = nil
    cmd_opts.use_cache = false

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

      opts.on('-b', '--blog-url blog', 'The blog url (e.g. myblog.tumblr.com)') do |blog_url|
        cmd_opts.blog_url = blog_url
      end
      opts.on('-k', '--apikey api-key', 'The tumblr api key used to call tumblr APIs') do |api_key|
        cmd_opts.api_key = api_key
      end
      opts.on('-c', '--use-cache', 'If set do not read from the net but from the cache') do |cache|
        cmd_opts.use_cache = cache
      end
      opts.on('-m', '--max-posts number', 'Max posts to read, all if not specified') do |max_posts|
        cmd_opts.max_posts = max_posts
      end
      opts.on('-p', '--prefix-cache prefix', 'The prefix path to prepend to cache directory') do |prefix_cache_dir|
        cmd_opts.prefix_cache_dir = prefix_cache_dir
      end

      opts.separator ''
      opts.on_tail('-h', '--help', 'This help text') do
        puts opts
        exit
      end
    end

    begin
      optparse.parse!
      mandatory = [:blog_url, :api_key]
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

    # puts "Performing task with options: #{cmd_opts.inspect}"

    cmd_opts
  end
end

opts = TumblrDownloader.parse_command_line
TumblrDownloader.new(opts).download

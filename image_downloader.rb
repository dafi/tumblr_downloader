#!/usr/bin/env ruby
# Download images from photo tumblr's posts

require 'open-uri'
require 'uri'
require 'json'
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'logger'

LOG_PATH = 'images.log'.freeze

def parse_command_line
  cmd_opts = OpenStruct.new
  cmd_opts.json_path = nil
  cmd_opts.image_path = nil

  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

    opts.on('-j', '--json-path path', 'The path containing the blog json files') do |v|
      cmd_opts.json_path = v
    end
    opts.on('-o', '--output path', 'The path where to save the images') do |v|
      cmd_opts.image_path = v
    end

    opts.separator ''
    opts.on_tail('-h', '--help', 'This help text') do
      puts opts
      exit
    end
  end

  begin
    optparse.parse!
    mandatory = %i[json_path image_path]
    missing = mandatory.select { |param| cmd_opts[param].nil? }
    unless missing.empty?
      puts "Missing options: #{missing.join(', ')}"
      puts optparse
      exit
    end
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
    puts $ERROR_INFO.to_s
    puts optparse
    exit
  end

  cmd_opts
end

# Error raised when an image can't be downloaded
class DownloadError < RuntimeError
  attr_reader :post
  def initialize(post)
    @post = post
  end
end

# Download images from photo tumblr's posts
class ImageDownloader
  def initialize(opts)
    @opts = opts
    @log = Logger.new(LOG_PATH)
  end

  def download
    FileUtils.mkdir_p(@opts.image_path) unless Dir.exist?(@opts.image_path)
    m = Dir.glob(File.join(@opts.json_path, '*.json'))
    file_count = m.length

    m.each_with_index do |f, i|
      puts "File #{File.basename(f)} of #{i + 1}/#{file_count} "
      begin
        process_json_file(f, @opts.image_path, false)
      rescue DownloadError => err
        log_download_error(err, File.basename(f))
        # sleep 25
      end
    end
  end

  def log_download_error(err, file_name)
    post = err.post
    puts "logged error for #{post['tags']}"
    @log.fatal("#{post['id']} #{post['tags']} file #{file_name}")
    @log.fatal(err.cause.to_s)
  end

  def process_json_file(json_path, root_dir, overwrite)
    json = JSON.parse(open(json_path).read)
    json['response']['posts'].each do |post|
      begin
        save_url_from_post(post, root_dir, overwrite)
      rescue
        raise DownloadError, post
      end
    end
  end

  def save_url_from_post(post, root_dir, overwrite)
    post_id = post['id']
    tag = post['tags'].empty? ? 'untagged' : post['tags'][0].downcase
    url = post['photos'][0]['original_size']['url']
    ext_file = url[/^.*(\..*)/, 1]
    ext_file ||= '.jpg'

    dest_dir = File.join(root_dir, dest_dir_by_tags(post['tags']))
    FileUtils.mkdir_p(dest_dir) unless Dir.exist?(dest_dir)
    puts "downloading #{post_id} for #{tag}"
    save_url(url, File.join(dest_dir, "#{post_id}#{ext_file}"), overwrite)
  end

  def dest_dir_by_tags(tags)
    return 'untagged' if tags.empty?
    tag = tags[0].downcase
    File.join(tag[0, 1], tag)
  end

  def save_url(url, dest_path, overwrite)
    return if !overwrite && File.exist?(dest_path)
    # read file before create the output
    # so if some exception is raised empty file isn't created
    content = open(url).read
    open(dest_path, 'wb') { |f| f << content }
  end
end

ImageDownloader.new(parse_command_line).download

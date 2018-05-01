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
ROUND_UP_PIXEL = [75, 100, 250, 400, 500, 540, 1280].freeze

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
    m = Dir.glob(File.join(@opts.json_path, '*.json')).sort! do |a, b|
      a.match(%r{.*/(\d+)})[1].to_i <=> b.match(%r{.*/(\d+)})[1].to_i
    end
    file_count = m.length

    m.each_with_index do |f, i|
      perc = (i + 1) * 100.0 / file_count
      puts "File #{File.basename(f)} of #{i + 1}/#{file_count} #{'%.2f' % perc}%"
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
      photo_info_list = []
      add_original_size_to_photo_info(post).each do |photo_info|
        path = build_destination_path(photo_info, root_dir, post)
        photo_info_list << [path, photo_info] if overwrite || !File.exist?(path)
      end

      begin
        save_url_from_post(post, photo_info_list) unless photo_info_list.empty?
      rescue
        raise DownloadError, post
      end
    end
  end

  # add original_size photo to alt_szies
  # if it differs from the largest image present on alt_sizes
  def add_original_size_to_photo_info(post)
    first_photo = post['photos'][0]
    alt_sizes = first_photo['alt_sizes']

    if alt_sizes[0]['url'] != first_photo['original_size']['url']
      alt_sizes << first_photo['original_size']
    end

    alt_sizes
  end

  def save_url_from_post(post, path_photo_info_tuple)
    tag = post['tags'].empty? ? 'untagged' : post['tags'][0].downcase
    print "downloading #{post['id']} for #{tag}:"
    threads = path_photo_info_tuple.map do |tuple|
      Thread.new do
        path, photo_info = tuple
        save_url(photo_info['url'], path)
        print " #{find_width(photo_info)}"
      end
    end
    threads.each(&:join)
    puts
  end

  def build_destination_path(photo_info, root_dir, post)
    size = find_width(photo_info) || 'unknown_width'
    dest_dir = File.join(root_dir, dest_dir_by_tags(post['tags']), size)
    FileUtils.mkdir_p(dest_dir) unless Dir.exist?(dest_dir)

    url = photo_info['url']
    ext_file = url[/^.*(\..*)/, 1] || '.jpg'
    File.join(dest_dir, "#{post['id']}#{ext_file}")
  end

  def find_width(photo_info)
    m = photo_info['url'].match(/(\d+)(?!.*\d)/)
    return m[1] if m
    width = photo_info['width']
    ROUND_UP_PIXEL.find { |w| width <= w }.to_s
  end

  def dest_dir_by_tags(tags)
    return 'untagged' if tags.empty?
    tag = tags[0].downcase
    File.join(tag[0, 1], tag)
  end

  def save_url(url, dest_path)
    # read file before create the output
    # so if some exception is raised the empty file isn't created
    content = open(url, read_timeout: 2, open_timeout: 3).read
    open(dest_path, 'wb') { |f| f << content }
  end
end

ImageDownloader.new(parse_command_line).download

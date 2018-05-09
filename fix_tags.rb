#!/usr/bin/env ruby
require 'oj'
require 'optparse'

# Add missing tags from PhotoShelf CSV to downloaded json files
class TagFixer
  def photoshelf_map(csv_path)
    tags_map = {}
    File.open(csv_path, 'r:UTF-8').each_line do |l|
      fields = l.split(';')
      post = fields[0].to_i
      tag = fields[2]

      tags = tags_map[post]
      if tags.nil?
        tags = []
        tags_map[post] = tags
      end
      tags << tag
    end
    tags_map
  end

  def create_post_lookup_table(json)
    posts = json['response']['posts']

    post_lookup = {}
    posts.each do |post|
      post_lookup[post['id']] = post
    end
    post_lookup
  end

  def tags_match?(tags1, tags2)
    return false unless tags1.length == tags2.length
    tags1.each_with_index do |tag, i|
      return false unless tag.casecmp?(tags2[i])
    end
    true
  end

  def fix_tags(post_lookup, tags_map)
    fixed = false
    post_lookup.each do |k, v|
      tags = tags_map[k]
      next if tags.nil? || tags_match?(tags, v['tags'])
      post_lookup[k]['tags'] = tags
      fixed = true
    end
    fixed
  end

  def fix_json(json, tags_map)
    fix_tags(create_post_lookup_table(json), tags_map)
  end

  def process_directory(photoshelf_path, json_path, out_dir)
    tags_map = photoshelf_map(photoshelf_path)

    Dir.glob(File.join(json_path, '*.json')) do |path|
      json = Oj.load(File.open(path, 'r:UTF-8').read)
      next unless fix_json(json, tags_map)
      fname = File.basename(path)
      File.open(File.join(out_dir, fname), 'w') { |f| f << Oj.generate(json) }
    end
  end

  def self.parse_command_line
    cmd_opts = OpenStruct.new
    cmd_opts.csv = nil
    cmd_opts.json_path = nil
    cmd_opts.out_dir = nil

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

      opts.on('-c', '--csv path', 'The CSV file created with PhotoShelf') do |csv|
        cmd_opts.csv = csv
      end
      opts.on('-j', '--json path', 'JSON path containing blog files') do |json_path|
        cmd_opts.json_path = json_path
      end
      opts.on('-o', '--output path', 'Output directory') do |out_dir|
        cmd_opts.out_dir = out_dir
      end

      opts.separator ''
      opts.on_tail('-h', '--help', 'This help text') do
        puts opts
        exit
      end
    end

    begin
      optparse.parse!
      mandatory = %i[csv json_path out_dir]
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
end

opts = TagFixer.parse_command_line
tf = TagFixer.new
tf.process_directory(opts.csv, opts.json_path, opts.out_dir)

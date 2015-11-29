# Download all tumblr public posts
# The posts (as JSON) are saved on local directory to speedup reload

require 'open-uri'
require "uri"
require "json"
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'set'

class TumblrDownloader
    def initialize(opts)
        @opts = opts

        @blog_url = TumblrDownloader.fix_url_domain(@opts.blog_url)
        if @opts.prefix_cache_dir
            @cache_dir = File.join(@opts.prefix_cache_dir, @blog_url)
        else
            @cache_dir = @blog_url
        end
        FileUtils.mkdir_p(@cache_dir) if !Dir.exist?(@cache_dir)
    end

    def read_json_write_cache(url, offset)
        offset_url = url
        if @opts.use_cache
            offset_url = File.join(@cache_dir, "#{offset}.json")
        else
            offset_url = "#{url}&offset=#{offset}"
        end
        text = open(offset_url).read

        # when reading from real url we must write to cache
        if !@opts.use_cache
            open(File.join(@cache_dir, "#{offset}.json"), 'wb') do |file|
                file << text
            end
        end

        return OpenStruct.new(JSON.parse(text))
    end

    def self.fix_url_domain(url)
        if url.include? "."
            return url
        end
        return url + ".tumblr.com"
    end

    # return the array where every index contains the read posts at that (tumblr) offset
    def download
        url = "https://api.tumblr.com/v2/blog/#{@blog_url}/posts/photo?api_key=#{@opts.api_key}"

        offset = 0
        all_posts = []
        posts = read_json_write_cache(url, offset)
        total_posts = @opts.max_posts ? @opts.max_posts.to_i : posts['response']['blog']['posts']

        while (offset < total_posts)
            puts "#{offset}/#{total_posts}"
            all_posts.push(posts)
            post_count = posts['response']['posts'].count;
            break if post_count == 0
            offset += post_count

            posts = read_json_write_cache(url, offset)
        end

        return all_posts
    end

    def write_tags(all_posts)
        all_tags = Set.new

        all_posts.each do |posts|
            posts['response']['posts'].each do |post|
                all_tags.merge(post['tags'].map { |tag| tag.downcase })
            end
        end
        open(File.join(@cache_dir, "tags.txt"), 'wb') do |file|
            file.puts(all_tags.to_a.sort)
        end
    end

    def self.html_for_tag_file(blog_url, tags_path)
        open(tags_path).read.split("\n").each do |tag|
            puts "<a href=\"http://#{blog_url}/tagged/#{tag}\">#{tag}</a><br/>"
        end
    end

    def self.parse_command_line()
        cmd_opts = OpenStruct.new
        cmd_opts.blog_url = nil
        cmd_opts.api_key = nil
        cmd_opts.use_cache = false

        optparse = OptionParser.new do |opts|
            opts.banner = "Usage: #{File.basename($0)} [options]"

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
            opts.on('-t', '--tags tags', 'Tags files used to generate HTML') do |tags_path|
                cmd_opts.tags_path = tags_path
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
            missing = mandatory.select{ |param| cmd_opts[param].nil? }
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

        return cmd_opts
    end
end

opts = TumblrDownloader.parse_command_line
if opts.tags_path
    TumblrDownloader.html_for_tag_file(TumblrDownloader.fix_url_domain(opts.blog_url), opts.tags_path)
else
    dl = TumblrDownloader.new(opts)
    all_posts = dl.download
    puts "Posts downloaded, writing tags..."
    dl.write_tags(all_posts)
end
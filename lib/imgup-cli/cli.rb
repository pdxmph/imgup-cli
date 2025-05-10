#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load('.env', File.expand_path('~/.imgup.env'))
require 'optparse'
require_relative 'config'
require_relative 'setup'         # SmugMug setup
require_relative 'uploader'

module ImgupCli
  class CLI
    def self.start(args = ARGV)
      # Allow: imgup setup [smugmug|flickr]
      if args[0] == 'setup'
        which = args[1] || 'smugmug'
        if which == 'smugmug'
          require_relative 'setup'
          ImgupCli::Setup.run(
            consumer_key:    ENV['SMUGMUG_TOKEN'],
            consumer_secret: ENV['SMUGMUG_SECRET']
          )
        elsif which == 'flickr'
          require_relative 'setup_flickr'
          ImgupCli::SetupFlickr.run
        else
          $stderr.puts "Unknown setup target: #{which.inspect}"
        end
        exit
      end

      # Load saved creds + ENV
      cfg = ImgupCli::Config.load
      ENV['SMUGMUG_TOKEN']         ||= cfg['consumer_key']
      ENV['SMUGMUG_SECRET']        ||= cfg['consumer_secret']
      ENV['SMUGMUG_ACCESS_TOKEN']  ||= cfg['access_token']
      ENV['SMUGMUG_ACCESS_TOKEN_SECRET'] ||= cfg['access_token_secret']
      ENV['FLICKR_KEY']            ||= cfg['flickr_key']
      ENV['FLICKR_SECRET']         ||= cfg['flickr_secret']
      ENV['FLICKR_ACCESS_TOKEN']   ||= cfg['flickr_access_token']
      ENV['FLICKR_ACCESS_TOKEN_SECRET'] ||= cfg['flickr_access_token_secret']
      ENV['SMUGMUG_UPLOAD_ALBUM_ID']   ||= cfg['album_id']

      options = { backend: 'smugmug', format: 'md' }
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: imgup [setup] | [options] <path>'
        opts.on('-b NAME', '--backend=NAME', 'Backend (smugmug|flickr)') { |b| options[:backend] = b }
        opts.on('-t TITLE','--title=TITLE','Image title')   { |v| options[:title]   = v }
        opts.on('-c CAPTION','--caption=CAPTION','Caption') { |v| options[:caption] = v }
        opts.on('-f F','--format=F',%w[org md html],'Format') { |v| options[:format]  = v }
        opts.on('-h','--help','Help') { puts opts; exit }
      end

      begin
        parser.parse!(args)
      rescue OptionParser::InvalidOption => e
        $stderr.puts e.message
        exit 1
      end

      image_path = args.first
      unless image_path && File.file?(image_path)
        $stderr.puts parser
        exit 1
      end

      begin
        uploader = Uploader.build(
          options[:backend],
          image_path,
          title:   options[:title],
          caption: options[:caption]
        )
        result = uploader.call

        snippet_key = (%w[org html].include?(options[:format]) ? options[:format] : 'markdown').to_sym
        puts result.fetch(snippet_key)
      rescue => e
        $stderr.puts e.message
        exit 1
      end
    end
  end
end

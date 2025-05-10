#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load('.env', File.expand_path('~/.imgup.env'))
require 'optparse'
require_relative 'config'
require_relative 'setup'
require_relative 'uploader'

module ImgupCli
  class CLI
    def self.start(args = ARGV)
      cfg = Config.load

      options = {
        backend: cfg['default_backend'] || 'smugmug',
        format:  cfg['default_format']  || 'md',
        title:   nil,
        caption: nil,
        tags:    []
      }

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: imgup [setup] | [options] <image_path>'

        opts.on('--set-backend BACKEND', 'Persist default backend') do |b|
          cfg['default_backend'] = b
          Config.save(cfg)
          puts "Default backend set to #{b}"
          exit
        end

        opts.on('--set-format FORMAT', %w[org md html], 'Persist default format') do |f|
          cfg['default_format'] = f
          Config.save(cfg)
          puts "Default format set to #{f}"
          exit
        end

        opts.on('-b NAME','--backend NAME','Select backend') { |b| options[:backend] = b }
        opts.on('-f F','--format F',%w[org md html],'Select output format') { |f| options[:format] = f }
        opts.on('-t T','--title T','Image title')    { |t| options[:title]   = t }
        opts.on('-c C','--caption C','Image caption'){ |c| options[:caption] = c }

        opts.on('--tags TAGS','Comma-separated tags') do |t|
          options[:tags] = t.split(/,\s*/)
        end

        opts.on('-h','--help','Show help') { puts opts; exit }
      end

      if args.first == 'setup'
        target = args[1] || 'smugmug'
        case target
        when 'smugmug'
          Setup.run(
            consumer_key:    cfg['consumer_key'],
            consumer_secret: cfg['consumer_secret']
          )
        when 'flickr'
          require_relative 'setup_flickr'
          SetupFlickr.run
        else
          STDERR.puts "Unknown setup target: #{target}"
        end
        exit
      end

      parser.parse!(args)
      image_path = args.first
      unless image_path && File.file?(image_path)
        STDERR.puts parser
        exit 1
      end

      uploader = Uploader.build(
        options[:backend],
        image_path,
        title:   options[:title],
        caption: options[:caption],
        tags:    options[:tags]
      )
      result = uploader.call

      output = case options[:format]
               when 'org'  then result[:org]
               when 'html' then result[:html]
               else            result[:markdown]
               end

      puts output
    end
  end
end

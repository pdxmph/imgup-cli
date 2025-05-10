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
      # 0) Load existing config
      cfg = Config.load

      # 1) Determine defaults (support old & new keys)
      default_backend = cfg['default_backend'] || cfg['backend'] || 'smugmug'
      default_format  = cfg['default_format']  || cfg['format']  || 'md'

      options = {
        backend: default_backend,
        format:  default_format,
        title:   nil,
        caption: nil
      }

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: imgup [setup] | [options] <image_path>'

        opts.on('--set-backend BACKEND', 'Persist default backend (smugmug|flickr)') do |b|
          cfg['default_backend'] = b
          cfg['backend']         = b    # for backwards compatibility
          Config.save(cfg)
          puts "→ Default backend saved as '#{b}' in #{Config::FILE}"
          exit
        end

        opts.on('--set-format FORMAT', %w[org md html], 'Persist default format') do |f|
          cfg['default_format'] = f
          cfg['format']         = f    # for backwards compatibility
          Config.save(cfg)
          puts "→ Default format saved as '#{f}' in #{Config::FILE}"
          exit
        end

        opts.on('-b NAME','--backend NAME','Select backend (smugmug|flickr)') do |b|
          options[:backend] = b
        end

        opts.on('-f F','--format F',%w[org md html],'Select output format') do |f|
          options[:format] = f
        end

        opts.on('-t T','--title T','Image title')    { |t| options[:title]   = t }
        opts.on('-c C','--caption C','Image caption'){ |c| options[:caption] = c }
        opts.on('-h','--help','Show help')           { puts opts; exit }
      end

      # 2) Handle `setup` subcommand
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
          STDERR.puts "Unknown setup target: #{target.inspect}"
        end
        exit
      end

      # 3) Parse flags
      begin
        parser.parse!(args)
      rescue OptionParser::InvalidOption => e
        STDERR.puts e.message
        exit 1
      end

      # 4) The remaining argument is the image path
      image_path = args.first
      unless image_path && File.file?(image_path)
        STDERR.puts parser
        exit 1
      end


      # 5) Perform the upload
      begin
        uploader = Uploader.build(
          options[:backend],
          image_path,
          title:   options[:title],
          caption: options[:caption]
        )
        result = uploader.call

        output = case options[:format]
                 when 'org'  then result[:org]
                 when 'html' then result[:html]
                 else            result[:markdown]
                 end

        puts output
      rescue => e
        STDERR.puts "Error: #{e.message}"
        exit 1
      end
    end
  end
end

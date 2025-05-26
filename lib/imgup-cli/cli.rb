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
        tags:    [],
        # New options for GoToSocial
        post_text: nil,
        images: [],
        visibility: 'public',
        resize: nil,
        verbose: false,
        fedi: false
      }

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: imgup [setup] | [options] <image_path> | [--post options]'

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

        # New GoToSocial options
        opts.on('--post TEXT', 'Main post text (for gotosocial)') do |p| 
          options[:post_text] = p
          options[:backend] = 'gotosocial' # Auto-switch to gotosocial
        end
        
        opts.on('--image PATH', 'Add an image (can be used multiple times)') do |path|
          options[:images] << { path: path, description: nil }
        end
        
        opts.on('--desc TEXT', 'Description for the last added image') do |desc|
          if options[:images].any?
            options[:images].last[:description] = desc
          else
            STDERR.puts "Warning: --desc used without preceding --image"
          end
        end
        
        opts.on('--visibility VIS', %w[public unlisted private direct], 
                'Post visibility (default: public)') do |v|
          options[:visibility] = v
        end
        
        opts.on('--resize DIMENSIONS', 'Resize images (e.g., 1920x1920, 1200x)') do |r|
          options[:resize] = r
        end
        
        opts.on('-v', '--verbose', 'Enable verbose output') do
          options[:verbose] = true
        end
        
        opts.on('--fedi', 'Also post to GoToSocial after upload') do
          options[:fedi] = true
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
        when 'gotosocial'
          require_relative 'setup_gotosocial'
          SetupGotosocial.run
        else
          STDERR.puts "Unknown setup target: #{target}"
        end
        exit
      end

      parser.parse!(args)
      
      # Handle different modes
      if options[:backend] == 'gotosocial' && !options[:fedi]
        # Direct GoToSocial mode (no other backend)
        if options[:images].empty?
          STDERR.puts "Error: GoToSocial posts require at least one --image"
          exit 1
        end
        
        uploader = Uploader.build(
          'gotosocial',
          nil, # no single path
          images: options[:images],
          post_text: options[:post_text],
          tags: options[:tags],
          visibility: options[:visibility],
          resize: options[:resize],
          verbose: options[:verbose]
        )
      elsif options[:images].any? && options[:fedi]
        # Multi-image upload to backend + fedi
        results = []
        options[:images].each_with_index do |img, idx|
          puts "Uploading #{File.basename(img[:path])} to #{options[:backend]}..." if options[:verbose]
          uploader = Uploader.build(
            options[:backend],
            img[:path],
            title:   img[:description] || File.basename(img[:path], '.*'),
            caption: img[:description],
            tags:    options[:tags]
          )
          results << uploader.call
        end
        
        # Post all to fedi
        require_relative 'fedi_poster'
        poster = FediPoster.new(
          results,
          post_text: options[:post_text],
          visibility: options[:visibility],
          verbose: options[:verbose]
        )
        fedi_url = poster.post
        
        # Output results
        results.each do |r|
          puts r[options[:format].to_sym]
        end
        puts "\nPosted to fediverse: #{fedi_url}" if fedi_url
        exit
      else
        # Traditional single-image mode
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
      end

      result = uploader.call

      # Handle fedi posting if requested
      if options[:fedi] && options[:backend] != 'gotosocial'
        require_relative 'fedi_poster'
        poster = FediPoster.new(
          result, 
          post_text: options[:post_text],
          visibility: options[:visibility],
          verbose: options[:verbose]
        )
        fedi_url = poster.post
        if fedi_url && options[:verbose]
          puts "\nPosted to fediverse: #{fedi_url}"
        end
      end

      output = case options[:format]
               when 'org'  then result[:org]
               when 'html' then result[:html]
               else            result[:markdown]
               end

      puts output
    end
  end
end

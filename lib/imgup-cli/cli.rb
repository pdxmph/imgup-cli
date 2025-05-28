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
        alt_text: nil,
        tags:    [],
        extract_metadata: true,
        review: false,
        # Social posting options
        post_text: nil,
        images: [],
        visibility: 'public',
        resize: nil,
        verbose: false,
        gotosocial: false,
        mastodon: false
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
        opts.on('--alt-text TEXT', 'Alt text for accessibility') { |a| options[:alt_text] = a }
        opts.on('--no-extract', 'Disable automatic metadata extraction') { options[:extract_metadata] = false }
        opts.on('--review', 'Review and edit metadata before upload') { options[:review] = true }
        opts.on('--tags TAGS','Comma-separated tags') do |t|
          options[:tags] = t.split(/,\s*/)
        end

        # Social posting options
        opts.on('--post TEXT', 'Post text for social platforms (requires --mastodon or --gotosocial)') do |p| 
          options[:post_text] = p
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
        
        opts.on('--gotosocial', 'Also post to GoToSocial after upload') do
          options[:gotosocial] = true
        end
        
        opts.on('--mastodon', 'Also post to Mastodon after upload') do
          options[:mastodon] = true
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
        when 'mastodon'
          require_relative 'setup_mastodon'
          SetupMastodon.run
        else
          STDERR.puts "Unknown setup target: #{target}"
          STDERR.puts "Valid options: smugmug, flickr, gotosocial, mastodon"
        end
        exit
      end

      parser.parse!(args)
      
      # Validation: --post requires either --mastodon or --gotosocial
      if options[:post_text] && !options[:mastodon] && !options[:gotosocial]
        STDERR.puts "Error: --post requires either --mastodon or --gotosocial"
        STDERR.puts parser
        exit 1
      end      
      # Handle different modes
      if options[:images].any? && (options[:gotosocial] || options[:mastodon])
        # Multi-image upload to backend + social sharing
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
        
        # Post to social platforms
        require_relative 'fedi_poster'
        
        # Use appropriate config based on flag
        config_prefix = options[:mastodon] ? 'mastodon' : 'gotosocial'
        
        poster = FediPoster.new(
          results,
          post_text: options[:post_text],
          visibility: options[:visibility],
          verbose: options[:verbose],
          config_prefix: config_prefix
        )
        fedi_url = poster.post
        
        # Output results
        results.each do |r|
          puts r[options[:format].to_sym]
        end
        puts "\nPosted to #{options[:mastodon] ? 'Mastodon' : 'GoToSocial'}: #{fedi_url}" if fedi_url
        exit
      end      
      # Traditional single-image mode
      image_path = args.first
      unless image_path && File.file?(image_path)
        STDERR.puts parser
        exit 1
      end

      # Extract metadata if enabled
      if options[:extract_metadata]
        require_relative 'metadata_extractor'
        begin
          metadata = MetadataExtractor.new(image_path).extract
          
          # Use extracted values as defaults, but CLI options override
          options[:alt_text] ||= metadata[:alt_text]
          options[:title] ||= metadata[:title]
          options[:caption] ||= metadata[:caption]
          options[:tags] = (options[:tags] + metadata[:tags]).uniq if metadata[:tags].any?
          
          puts "Extracted metadata from image:" if options[:verbose]
          puts "  Alt text: #{options[:alt_text]}" if options[:verbose] && options[:alt_text]
          puts "  Title: #{options[:title]}" if options[:verbose] && options[:title]
          puts "  Tags: #{options[:tags].join(', ')}" if options[:verbose] && options[:tags].any?
        rescue => e
          puts "Warning: Could not extract metadata: #{e.message}" if options[:verbose]
        end
      end
      
      # Review metadata if requested
      if options[:review]
        puts "\nMetadata for upload:"
        puts "  Title: #{options[:title] || '(none)'}"
        puts "  Alt text: #{options[:alt_text] || '(none)'}"
        puts "  Caption: #{options[:caption] || '(none)'}"
        puts "  Tags: #{options[:tags].any? ? options[:tags].join(', ') : '(none)'}"
        
        print "\nProceed with upload? (y/n/e[dit]): "
        response = STDIN.gets.chomp.downcase
        
        if response == 'e' || response == 'edit'
          # Simple editing interface
          print "Title [#{options[:title]}]: "
          input = STDIN.gets.chomp
          options[:title] = input unless input.empty?
          
          print "Alt text [#{options[:alt_text]}]: "
          input = STDIN.gets.chomp
          options[:alt_text] = input unless input.empty?
          
          print "Caption [#{options[:caption]}]: "
          input = STDIN.gets.chomp
          options[:caption] = input unless input.empty?
          
          print "Tags (comma-separated) [#{options[:tags].join(', ')}]: "
          input = STDIN.gets.chomp
          options[:tags] = input.split(/,\s*/) unless input.empty?
        elsif response != 'y'
          puts "Upload cancelled."
          exit
        end
      end

      uploader = Uploader.build(
        options[:backend],
        image_path,
        title:   options[:title],
        caption: options[:caption],
        alt_text: options[:alt_text],
        tags:    options[:tags]
      )
      
      result = uploader.call

      # Handle social posting if requested
      if options[:gotosocial] || options[:mastodon]
        require_relative 'fedi_poster'
        
        # Use appropriate config based on flag
        config_prefix = options[:mastodon] ? 'mastodon' : 'gotosocial'
        
        poster = FediPoster.new(
          result, 
          post_text: options[:post_text],
          visibility: options[:visibility],
          verbose: options[:verbose],
          config_prefix: config_prefix
        )
        fedi_url = poster.post
      end

      # Output the snippet first
      output = case options[:format]
               when 'org'  then result[:org]
               when 'html' then result[:html]
               else            result[:markdown]
               end

      puts output
      
      # Then show social media post info
      if (options[:gotosocial] || options[:mastodon]) && fedi_url
        puts "\nPosted to #{options[:mastodon] ? 'Mastodon' : 'GoToSocial'}: #{fedi_url}"
      end
    end
  end
end
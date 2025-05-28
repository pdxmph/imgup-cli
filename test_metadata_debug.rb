#!/usr/bin/env ruby
# test_metadata_debug.rb - Debug metadata extraction

require_relative 'lib/imgup-cli/metadata_extractor'
require 'exifr/jpeg'
require 'pp'

if ARGV.empty?
  puts "Usage: #{$0} <image_file>"
  exit 1
end

image_path = ARGV[0]
unless File.exist?(image_path)
  puts "File not found: #{image_path}"
  exit 1
end

puts "Debug metadata extraction for: #{image_path}"
puts "-" * 50

begin
  # Show raw EXIF data
  if image_path.downcase.end_with?('.jpg', '.jpeg')
    exif = EXIFR::JPEG.new(image_path)
    puts "\nEXIF fields available:"
    
    # Common metadata fields
    %i[image_description document_name title keywords copyright artist].each do |field|
      if exif.respond_to?(field)
        value = exif.send(field)
        puts "  #{field}: #{value.inspect}" if value
      end
    end
    
    # Show all available EXIF methods (filtered)
    puts "\nOther EXIF methods with values:"
    interesting_methods = exif.methods - Object.methods
    interesting_methods.sort.each do |method|
      next if method.to_s.end_with?('=') || method.to_s.start_with?('_')
      begin
        value = exif.send(method)
        if value && !value.nil? && value != "" && !value.is_a?(Method)
          case value
          when String, Numeric, Symbol, TrueClass, FalseClass
            puts "  #{method}: #{value}"
          when Array
            puts "  #{method}: #{value.inspect}" if value.any?
          end
        end
      rescue
        # Skip methods that need arguments
      end
    end
  end
  
  puts "\n" + "-" * 50
  extractor = ImgupCli::MetadataExtractor.new(image_path)
  metadata = extractor.extract
  
  puts "\nExtracted metadata:"
  puts "  Alt text: #{metadata[:alt_text]}"
  puts "  Title: #{metadata[:title]}"
  puts "  Caption: #{metadata[:caption]}"
  puts "  Tags: #{metadata[:tags].join(', ')}" if metadata[:tags].any?
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end

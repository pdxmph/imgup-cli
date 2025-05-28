#!/usr/bin/env ruby
# test_metadata.rb - Test metadata extraction

require_relative 'lib/imgup-cli/metadata_extractor'

if ARGV.empty?
  puts "Usage: #{$0} <image_file>"
  exit 1
end

image_path = ARGV[0]
unless File.exist?(image_path)
  puts "File not found: #{image_path}"
  exit 1
end

puts "Testing metadata extraction for: #{image_path}"
puts "-" * 50

begin
  extractor = ImgupCli::MetadataExtractor.new(image_path)
  metadata = extractor.extract
  
  puts "Extracted metadata:"
  puts "  Alt text: #{metadata[:alt_text]}"
  puts "  Title: #{metadata[:title]}"
  puts "  Caption: #{metadata[:caption]}"
  puts "  Tags: #{metadata[:tags].join(', ')}" if metadata[:tags].any?
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end

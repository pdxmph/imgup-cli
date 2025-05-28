#!/usr/bin/env ruby
# Test script to verify metadata extraction without uploading

require 'bundler/setup'
require_relative 'lib/imgup-cli/metadata_extractor'

path = ARGV[0] || 'test/fixtures/IMG_0062.jpeg'
puts "Testing metadata extraction for: #{path}"
puts "=" * 60

extractor = ImgupCli::MetadataExtractor.new(path)
metadata = extractor.extract

puts "\nExtracted metadata:"
puts "  Title: #{metadata[:title]}"
puts "  Alt text: #{metadata[:alt_text]}"
puts "  Caption: #{metadata[:caption]}"
puts "  Tags: #{metadata[:tags].join(', ')}"

puts "\nThis is what imgup will use:"
puts "  SmugMug/Flickr title: #{metadata[:title]}"
puts "  HTML alt attribute: #{metadata[:alt_text]}"
puts "  Social media description: #{metadata[:alt_text]}"
puts "  Service tags: #{metadata[:tags].join(', ')}"

puts "\nExample outputs:"
puts "  Markdown: ![#{metadata[:alt_text]}](https://example.com/image.jpg)"
puts "  HTML: <img src=\"https://example.com/image.jpg\" alt=\"#{metadata[:alt_text]}\" />"
puts "  Org: [[img:https://example.com/image.jpg][#{metadata[:alt_text]}]]"

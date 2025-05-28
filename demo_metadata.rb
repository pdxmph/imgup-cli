#!/usr/bin/env ruby
# demo_metadata.rb - Demonstrate metadata extraction features

require_relative 'lib/imgup-cli/metadata_extractor'

def demo_metadata(image_path)
  puts "=" * 60
  puts "imgup-cli Metadata Extraction Demo"
  puts "=" * 60
  
  extractor = ImgupCli::MetadataExtractor.new(image_path)
  metadata = extractor.extract
  
  puts "\nImage: #{image_path}"
  puts "\nExtracted Metadata:"
  puts "  Alt text: #{metadata[:alt_text]}"
  puts "  Title: #{metadata[:title]}"
  puts "  Caption: #{metadata[:caption]}"
  puts "  Tags: #{metadata[:tags].join(', ')}" if metadata[:tags].any?
  
  puts "\nGenerated snippets would be:"
  
  # Simulate what the uploaders would generate
  fake_url = "https://example.com/image.jpg"
  
  puts "\nMarkdown:"
  puts "  ![#{metadata[:alt_text]}](#{fake_url})"
  
  puts "\nHTML:"
  puts "  <img src=\"#{fake_url}\" alt=\"#{metadata[:alt_text]}\" />"
  
  puts "\nOrg-mode:"
  puts "  [[img:#{fake_url}][#{metadata[:alt_text]}]]"
  
  puts "\nNote: The key improvement is that alt text is now:"
  puts "  1. Extracted from image metadata automatically"
  puts "  2. Separated from the title conceptually"
  puts "  3. Used for accessibility in all output formats"
  puts "  4. Passed to social media platforms for image descriptions"
end

# Run demo on test images
if ARGV.any?
  ARGV.each { |path| demo_metadata(path) if File.exist?(path) }
else
  Dir.glob("test/fixtures/*.jpg").first(2).each { |path| demo_metadata(path) }
end

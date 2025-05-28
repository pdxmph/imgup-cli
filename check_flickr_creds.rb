#!/usr/bin/env ruby
# Script to check and clear Flickr credentials

require 'bundler/setup'
require_relative 'lib/imgup-cli/config'

creds = ImgupCli::Config.load

puts "Current Flickr configuration:"
puts "  API Key: #{creds['flickr_key'] || '(not set)'}"
puts "  Secret: #{creds['flickr_secret'] ? '[REDACTED]' : '(not set)'}"
puts "  Access Token: #{creds['flickr_access_token'] ? '[PRESENT]' : '(not set)'}"
puts

if ARGV[0] == '--clear'
  creds.delete('flickr_key')
  creds.delete('flickr_secret')
  creds.delete('flickr_access_token')
  creds.delete('flickr_access_token_secret')
  ImgupCli::Config.save(creds)
  puts "✅ Flickr credentials cleared!"
elsif creds['flickr_key'] || creds['flickr_secret']
  puts "To clear Flickr credentials and start fresh, run:"
  puts "  ruby check_flickr_creds.rb --clear"
end

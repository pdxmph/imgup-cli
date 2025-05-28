#!/usr/bin/env ruby
# Debug Flickr OAuth issues

require 'bundler/setup'
require 'flickraw'
require 'time'

# Check system time
puts "System time: #{Time.now}"
puts "UTC time: #{Time.now.utc}"
puts

# Test credentials (you'll need to replace with your actual ones)
print "Enter Flickr API Key: "
api_key = STDIN.gets.strip

print "Enter Flickr Secret: "
api_secret = STDIN.gets.strip

FlickRaw.api_key = api_key
FlickRaw.shared_secret = api_secret

puts "\nTesting Flickr OAuth..."
puts "API Key: #{api_key}"
puts "Secret: [REDACTED]"

begin
  flickr = FlickRaw::Flickr.new
  puts "\nAttempting to get request token..."
  token = flickr.get_request_token(oauth_callback: 'oob')
  puts "✅ Success! Got request token: #{token['oauth_token'][0..10]}..."
rescue => e
  puts "❌ Error: #{e.class} - #{e.message}"
  
  if e.message.include?('signature_invalid')
    puts "\nPossible causes:"
    puts "1. Invalid API key or secret"
    puts "2. System clock is out of sync (OAuth requires accurate time)"
    puts "3. Special characters in credentials not properly handled"
    puts "\nTry:"
    puts "- Regenerating your API credentials at https://www.flickr.com/services/apps/by/me"
    puts "- Checking your system time: date -u"
  end
end

# lib/imgup-cli/setup_mastodon.rb
require_relative 'config'

module ImgupCli
  class SetupMastodon
    def self.run
      cfg = Config.load
      
      puts "\n🐘 Mastodon Setup"
      puts "="*50
      
      print "\nMastodon instance URL (e.g., https://mastodon.social): "
      instance_url = STDIN.gets.strip.sub(/\/$/, '')
      
      puts "\nTo get your access token:"
      puts "1. Go to: #{instance_url}/settings/applications"
      puts "2. Click 'New application'"
      puts "3. Name: imgup (or anything you like)"
      puts "4. Redirect URI: urn:ietf:wg:oauth:2.0:oob"
      puts "5. Scopes: read, write"
      puts "6. Submit and copy 'Your access token'"
      
      print "\nPaste your access token: "
      access_token = STDIN.gets.strip
      
      # Test the connection
      puts "\n🔍 Testing connection..."
      if test_connection(instance_url, access_token)
        cfg.merge!(
          'mastodon_instance' => instance_url,
          'mastodon_token' => access_token,
          # Also save as gotosocial for compatibility
          'gotosocial_instance' => instance_url,
          'gotosocial_token' => access_token
        )
        Config.save(cfg)
        puts "\n✅ Mastodon setup complete!"
        puts "You can now use --backend mastodon or --backend gotosocial"
      else
        puts "\n❌ Failed to connect. Please check your instance URL and token."
      end
    end
    
    private
    
    def self.test_connection(instance_url, token)
      require 'net/http'
      require 'json'
      
      uri = URI("#{instance_url}/api/v1/accounts/verify_credentials")
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{token}"
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      
      response = http.request(req)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        puts "✅ Connected as @#{data['username']}@#{uri.host}"
        true
      else
        false
      end
    rescue => e
      puts "❌ Error: #{e.message}"
      false
    end
  end
end

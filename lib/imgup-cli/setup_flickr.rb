# lib/imgup-cli/setup_flickr.rb
require 'flickraw'
require 'launchy'
require_relative 'config'

module ImgupCli
  class SetupFlickr
    CALLBACK = 'oob'

    def self.run
      creds = Config.load

      # Get API credentials
      api_key = creds['flickr_key'] || ask("Flickr API Key")
      api_secret = creds['flickr_secret'] || ask("Flickr Secret")
      
      # Trim whitespace that might cause issues
      api_key = api_key.strip
      api_secret = api_secret.strip
      
      # Save credentials immediately to avoid losing them on error
      creds['flickr_key'] = api_key
      creds['flickr_secret'] = api_secret
      Config.save(creds)
      
      # Set up FlickRaw
      FlickRaw.api_key = api_key
      FlickRaw.shared_secret = api_secret

      flickr = FlickRaw::Flickr.new
      
      begin
        token = flickr.get_request_token(oauth_callback: CALLBACK)
      rescue FlickRaw::OAuthClient::FailedResponse => e
        if e.message.include?('signature_invalid')
          puts "\n❌ OAuth signature invalid. This could mean:"
          puts "   - The API key or secret is incorrect"
          puts "   - Your system clock is out of sync"
          puts "   - The credentials need to be regenerated"
          puts "\nPlease verify your API credentials at:"
          puts "https://www.flickr.com/services/apps/by/me"
          raise
        else
          raise
        end
      end
      auth_url = flickr.get_authorize_url(token['oauth_token'], perms: 'write')

      puts "Authorize here:\n\n  #{auth_url}\n\n"
      Launchy.open(auth_url)
      print "Enter the verifier code: "
      verifier = STDIN.gets.strip

      access = flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verifier)
      creds.merge!(
        'flickr_key'                => FlickRaw.api_key,
        'flickr_secret'             => FlickRaw.shared_secret,
        'flickr_access_token'       => access['oauth_token'],
        'flickr_access_token_secret'=> access['oauth_token_secret']
      )
      Config.save(creds)
      puts "\n✅ Flickr setup complete!"
    end

    def self.ask(prompt)
      print "#{prompt}: "
      STDIN.gets.strip
    end
  end
end

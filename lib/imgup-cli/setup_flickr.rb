# lib/imgup-cli/setup_flickr.rb
require 'flickraw'
require 'launchy'
require_relative 'config'

module ImgupCli
  class SetupFlickr
    CALLBACK = 'oob'

    def self.run
      creds = Config.load

      FlickRaw.api_key       = creds['flickr_key']    || ask("Flickr API Key")
      FlickRaw.shared_secret = creds['flickr_secret'] || ask("Flickr Secret")

      flickr = FlickRaw::Flickr.new
      token  = flickr.get_request_token(oauth_callback: CALLBACK)
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

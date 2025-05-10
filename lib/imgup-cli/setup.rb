# lib/imgup-cli/setup.rb
require 'oauth'
require 'launchy'
require 'json'
require 'uri'
require 'cgi'
require_relative 'config'

module ImgupCli
  class Setup
    API_BASE           = 'https://api.smugmug.com'
    REQUEST_TOKEN_URL  = "#{API_BASE}/services/oauth/1.0a/getRequestToken"
    AUTHORIZE_URL      = "#{API_BASE}/services/oauth/1.0a/authorize"
    ACCESS_TOKEN_URL   = "#{API_BASE}/services/oauth/1.0a/getAccessToken"
    USER_ENDPOINT      = '/api/v2!authuser'
    CHILDREN_SUFFIX    = '!children'

    # consumer_key and consumer_secret may be passed in,
    # but if missing we’ll load from config/env or prompt the user.
    def self.run(consumer_key: nil, consumer_secret: nil)
      cfg = ImgupCli::Config.load

      # --- Determine your SmugMug API credentials --------------------------------
      consumer_key    ||= cfg['consumer_key']    || ENV['SMUGMUG_TOKEN']
      consumer_secret ||= cfg['consumer_secret'] || ENV['SMUGMUG_SECRET']

      if consumer_key.to_s.strip.empty? || consumer_secret.to_s.strip.empty?
        puts "To continue, I need your SmugMug API Key & Secret."
        print "API Key: "
        consumer_key = STDIN.gets.strip
        print "API Secret: "
        consumer_secret = STDIN.gets.strip
        puts
      end

      # --- 1) Obtain a PIN-mode request token -----------------------------------
      consumer = OAuth::Consumer.new(
        consumer_key,
        consumer_secret,
        request_token_url: REQUEST_TOKEN_URL,
        authorize_url:     AUTHORIZE_URL,
        access_token_url:  ACCESS_TOKEN_URL
      )
      request_token = consumer.get_request_token(oauth_callback: 'oob')

      # --- 2) Direct user to authorize in browser -------------------------------
      auth_url = "#{AUTHORIZE_URL}?oauth_token=#{request_token.token}&Access=Full&Permissions=Modify"
      puts "\nPlease authorize this app in your browser:\n\n  #{auth_url}\n\n"
      Launchy.open(auth_url)

      # --- 3) Prompt for the full callback URL and extract the PIN -------------
      puts "After authorizing, SmugMug will attempt to redirect and fail."
      print "Paste the full callback URL here: "
      redirect_url = STDIN.gets.strip
      uri    = URI.parse(redirect_url)
      params = CGI.parse(uri.query.to_s)
      verifier = params['oauth_verifier']&.first
      abort "❌ Couldn't find oauth_verifier in that URL." unless verifier
      puts "→ Got PIN: #{verifier}"

      # --- 4) Exchange PIN for an access token ---------------------------------
      access_token = request_token.get_access_token(oauth_verifier: verifier)

      # --- 5) Persist OAuth credentials ----------------------------------------
      cfg.merge!(
        'consumer_key'        => consumer_key,
        'consumer_secret'     => consumer_secret,
        'access_token'        => access_token.token,
        'access_token_secret' => access_token.secret
      )

      # --- 6) Build OAuth client for SmugMug API calls -------------------------
      api_consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: API_BASE)
      api_access   = OAuth::AccessToken.new(api_consumer,
                                            access_token.token,
                                            access_token.secret)

      # --- 7) Fetch your root node URI ----------------------------------------
      puts "\nDiscovering your root node…"
      raw_user  = api_access.get(USER_ENDPOINT, 'Accept' => 'application/json').body
      user_data = JSON.parse(raw_user)
      root_node = user_data.dig('Response','User','Uris','Node','Uri')
      abort "❌ Could not find root node URI. Payload:\n#{JSON.pretty_generate(user_data)}" unless root_node

      # --- 8) Retrieve child nodes (folders & public albums) -------------------
      puts "\nFetching your public albums…"
      raw_children  = api_access.get("#{root_node}#{CHILDREN_SUFFIX}", 'Accept' => 'application/json').body
      children_data = JSON.parse(raw_children)
      nodes         = children_data.dig('Response','Node') || []

      # --- 9) Filter for album-type nodes -------------------------------------
      albums = nodes.select { |n| n['Type'] == 'Album' }
      abort "❌ No public albums found. Payload:\n#{JSON.pretty_generate(children_data)}" if albums.empty?

      # --- 10) Prompt user to select an album ---------------------------------
      puts "\nSelect an album to upload into:"
      albums.each_with_index do |n, idx|
        title     = n['Name'].to_s.strip.empty? ? 'Untitled' : n['Name']
        album_uri = n.dig('Uris','Album','Uri')
        key       = album_uri.split('/').last
        puts "#{idx + 1}. #{title} (ID: #{key})"
      end
      print "\nEnter the number [1-#{albums.size}]: "
      choice = STDIN.gets.to_i
      abort "❌ Invalid selection." unless choice.between?(1, albums.size)

      selected  = albums[choice - 1]
      album_uri = selected.dig('Uris','Album','Uri')
      album_key = album_uri.split('/').last
      cfg['album_id'] = album_key
      puts "→ Selected album: #{selected['Name']} (#{album_key})"

      # --- 11) Save configuration ---------------------------------------------
      ImgupCli::Config.save(cfg)
      puts "\n✅ Setup complete!  Config written to:\n    #{ImgupCli::Config::FILE}\n\n"
    rescue OAuth::Unauthorized => e
      abort "Authorization failed: #{e.message}"
    end
  end
end

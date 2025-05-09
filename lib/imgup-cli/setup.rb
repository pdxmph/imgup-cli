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
    CHILDREN_FLAG      = '!children'

    def self.run(consumer_key:, consumer_secret:)
      cfg = ImgupCli::Config.load

      # 1) Do PIN‐mode request token dance
      consumer      = OAuth::Consumer.new(
                        consumer_key,
                        consumer_secret,
                        request_token_url: REQUEST_TOKEN_URL,
                        authorize_url:     AUTHORIZE_URL,
                        access_token_url:  ACCESS_TOKEN_URL
                      )
      request_token = consumer.get_request_token(oauth_callback: 'oob')

      # 2) Let user authorize in browser
      auth_url = "#{AUTHORIZE_URL}?oauth_token=#{request_token.token}&Access=Full&Permissions=Modify"
      puts "\nPlease authorize this app here:\n\n  #{auth_url}\n\n"
      Launchy.open(auth_url)

      # 3) Capture the redirect URL with the PIN
      print "After authorizing, paste the full callback URL here: "
      redirect_url = STDIN.gets.strip

      # 4) Extract PIN
      verifier = CGI.parse(URI.parse(redirect_url).query)['oauth_verifier'].first rescue nil
      abort "❌ Couldn't extract PIN from that URL." unless verifier
      puts "→ Got PIN: #{verifier}"

      # 5) Exchange PIN for real access token
      access_token = request_token.get_access_token(oauth_verifier: verifier)

      # 6) Persist OAuth credentials
      cfg.merge!(
        'consumer_key'        => consumer_key,
        'consumer_secret'     => consumer_secret,
        'access_token'        => access_token.token,
        'access_token_secret' => access_token.secret
      )

      # 7) Discover root node from user record
      api_consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: API_BASE)
      api_access   = OAuth::AccessToken.new(api_consumer, access_token.token, access_token.secret)

      user_raw  = api_access.get("#{USER_ENDPOINT}?_expand=Uris", 'Accept' => 'application/json').body
      user_data = JSON.parse(user_raw)
      root_node = user_data.dig('Response','User','Uris','Node','Uri')
      abort "❌ Cannot find root node URI. Full payload:\n#{JSON.pretty_generate(user_data)}" unless root_node

      # 8) Fetch children (only public albums/folders)
      children_url  = "#{root_node}#{CHILDREN_FLAG}?_expand=Album"
      puts "\nFetching your public albums…"
      raw_children  = api_access.get(children_url, 'Accept' => 'application/json').body
      children_data = JSON.parse(raw_children)
      nodes         = children_data.dig('Response','Node') || []

      # 9) Filter for those that are albums
      albums = nodes.select { |n| n['Type'] == 'Album' }
      abort "❌ No public albums found. Full response:\n#{JSON.pretty_generate(children_data)}" if albums.empty?

      # 10) List and choose
      puts "\nSelect a public album to upload into:"
      albums.each_with_index do |n, i|
        title = n['Name'].to_s.strip.empty? ? 'Untitled' : n['Name']
        uri   = n.dig('Uris','Album','Uri')
        key   = uri.split('/').last
        puts "#{i + 1}. #{title} (ID: #{key})"
      end
      print "\nEnter number [1-#{albums.size}]: "
      choice = STDIN.gets.to_i
      abort "❌ Invalid selection." unless choice.between?(1, albums.size)

      sel = albums[choice - 1]
      cfg['album_id'] = sel.dig('Uris','Album','Uri').split('/').last
      puts "→ Selected album: #{sel['Name']} (#{cfg['album_id']})"

      # 11) Save config
      ImgupCli::Config.save(cfg)
      puts "\n✅ Setup complete!  Config written to:\n    #{ImgupCli::Config::FILE}\n\n"
    rescue OAuth::Unauthorized => e
      abort "Authorization failed: #{e.message}"
    end
  end
end

# lib/imgup-cli/setup_gotosocial.rb
require 'securerandom'
require 'webrick'
require 'launchy'
require 'net/http'
require 'json'
require_relative 'config'

module ImgupCli
  class SetupGotosocial
    def self.run
      cfg = Config.load
      
      print "GoToSocial instance URL (e.g., https://social.example.com): "
      instance_url = STDIN.gets.strip.sub(/\/$/, '')
      
      puts "\nYou'll need to create an application on your GoToSocial instance."
      puts "Go to: #{instance_url}/settings/applications/new"
      puts "\nApplication settings:"
      puts "  Name: imgup"
      puts "  Redirect URI: http://localhost:8888/callback"
      puts "  Scopes: read write"
      
      print "\nPaste your Client ID: "
      client_id = STDIN.gets.strip
      
      print "Paste your Client Secret: "
      client_secret = STDIN.gets.strip
      
      # OAuth2 flow
      state = SecureRandom.hex(16)
      auth_url = "#{instance_url}/oauth/authorize?" + URI.encode_www_form(
        client_id: client_id,
        response_type: 'code',
        redirect_uri: 'http://localhost:8888/callback',
        scope: 'read write',
        state: state
      )
      
      # Start local server to catch callback
      server = WEBrick::HTTPServer.new(Port: 8888, Logger: WEBrick::Log.new(nil, 0))
      code = nil
      
      server.mount_proc '/callback' do |req, res|
        if req.query['state'] == state
          code = req.query['code']
          res.body = "✅ Authorization received! You can close this window."
        else
          res.body = "❌ Invalid state parameter!"
        end
        server.shutdown
      end
      
      puts "\nOpening browser for authorization..."
      Launchy.open(auth_url)
      
      Thread.new { server.start }
      sleep 1 until code
      
      # Exchange code for token
      token_uri = URI("#{instance_url}/oauth/token")
      req = Net::HTTP::Post.new(token_uri)
      req.set_form_data(
        grant_type: 'authorization_code',
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: 'http://localhost:8888/callback'
      )
      
      response = Net::HTTP.start(token_uri.hostname, token_uri.port, use_ssl: true) do |http|
        http.request(req)
      end
      
      token_data = JSON.parse(response.body)
      
      cfg.merge!(
        'gotosocial_instance' => instance_url,
        'gotosocial_token' => token_data['access_token']
      )
      Config.save(cfg)
      
      puts "\n✅ GoToSocial setup complete!"
    end
  end
end

# lib/imgup-cli/fedi_poster.rb
require 'net/http'
require 'uri'
require 'json'
require 'open-uri'
require 'tempfile'
require 'net/http/post/multipart'
require_relative 'config'

module ImgupCli
  # Posts to GoToSocial using URLs from other services
  class FediPoster
    def initialize(upload_results, post_text: nil, visibility: 'public', verbose: false, config_prefix: 'gotosocial')
      # Properly handle single result (hash) vs multiple results (array)
      @upload_results = upload_results.is_a?(Array) ? upload_results : [upload_results]
      @post_text = post_text
      @visibility = visibility
      @verbose = verbose
      @config_prefix = config_prefix
      
      cfg = Config.load
      @instance_url = cfg["#{config_prefix}_instance"]
      @access_token = cfg["#{config_prefix}_token"]
      
      unless @instance_url && @access_token
        puts "⚠️  #{config_prefix.capitalize} not configured. Run 'imgup setup #{config_prefix}' first." if @verbose
        @configured = false
      else
        @configured = true
      end
    end
    
    def post
      return nil unless @configured
      
      puts "\n📱 Posting to GoToSocial..." if @verbose
      
      # Download images from service URLs and upload to GoToSocial
      media_ids = @upload_results.map do |result|
        download_and_upload(result)
      end.compact
      
      return nil if media_ids.empty?
      
      # Collect all tags from uploads
      all_tags = @upload_results.flat_map { |r| r[:tags] || [] }.uniq
      hashtags = all_tags.map { |t| "##{t.gsub(/[^a-zA-Z0-9]/, '')}" }
      
      # Build status text
      status_text = @post_text || @upload_results.first[:title] || ""
      status_text += "\n\n" + hashtags.join(' ') unless hashtags.empty?
      
      # Create post with media attachments
      params = {
        'status' => status_text,
        'visibility' => @visibility,
        'media_ids' => media_ids
      }
      
      uri = URI("#{@instance_url}/api/v1/statuses")
      req = Net::HTTP::Post.new(uri.path)
      req['Authorization'] = "Bearer #{@access_token}"
      req['Content-Type'] = 'application/json'
      req.body = params.to_json
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      response = http.request(req)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        post_url = data['url']
        puts "✅ Posted to fediverse: #{post_url}" if @verbose
        post_url
      else
        puts "❌ Fedi post failed: #{response.code} #{response.message}" if @verbose
        nil
      end
    rescue => e
      puts "❌ Fedi post error: #{e.message}" if @verbose
      nil
    end
    
    private
    
    def download_and_upload(result)
      return nil unless result[:image_url]
      
      puts "  → Downloading from #{result[:image_url].split('/').last}..." if @verbose
      
      # Download image to temp file
      temp_file = Tempfile.new(['imgup_fedi', File.extname(result[:image_url])])
      begin
        URI.open(result[:image_url]) do |remote_file|
          temp_file.write(remote_file.read)
          temp_file.rewind
        end
        
        # Upload to GoToSocial
        upload_to_gotosocial(temp_file.path, result[:alt_text] || result[:caption] || result[:title])
      ensure
        temp_file.close
        temp_file.unlink
      end
    rescue => e
      puts "    ❌ Failed to process #{result[:image_url]}: #{e.message}" if @verbose
      nil
    end
    
    def upload_to_gotosocial(file_path, description)
      uri = URI("#{@instance_url}/api/v1/media")
      
      File.open(file_path, 'rb') do |file|
        req = Net::HTTP::Post::Multipart.new(uri.path,
          'file' => UploadIO.new(file, 'image/jpeg', File.basename(file_path)),
          'description' => description || ''
        )
        req['Authorization'] = "Bearer #{@access_token}"
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        response = http.request(req)
        
        if response.code == '200'
          data = JSON.parse(response.body)
          puts "    ✅ Uploaded as media ID: #{data['id']}" if @verbose
          data['id']
        else
          puts "    ❌ Upload failed: #{response.code}" if @verbose
          nil
        end
      end
    end
  end
end

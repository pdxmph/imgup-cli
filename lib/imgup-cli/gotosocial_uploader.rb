# lib/imgup-cli/gotosocial_uploader.rb
require 'net/http'
require 'uri'
require 'json'
require 'net/http/post/multipart'
require_relative 'config'

module ImgupCli
  class GotosocialUploader
    MAX_IMAGES = 4  # Mastodon API limit
    
    def initialize(path = nil, images: [], post_text: nil, tags: [], visibility: 'public', **_opts)
      @images = images
      @post_text = post_text || ''
      @tags = Array(tags).map { |t| "##{t.gsub(/[^a-zA-Z0-9]/, '')}" }
      @visibility = visibility
      
      cfg = Config.load
      @instance_url = cfg['gotosocial_instance'] || abort("❌ No GoToSocial instance configured")
      @access_token = cfg['gotosocial_token'] || abort("❌ No GoToSocial token configured")
      
      if @images.size > MAX_IMAGES
        abort("❌ Too many images: #{@images.size} (max: #{MAX_IMAGES})")
      end
    end
    
    def call
      # Upload all media files first
      puts "📤 Uploading #{@images.size} image(s)..."
      media_ids = @images.map.with_index do |img, idx|
        puts "  → Uploading #{File.basename(img[:path])}..."
        upload_media(img[:path], img[:description])
      end
      
      # Give GoToSocial a moment to process the images
      puts "⏳ Waiting for image processing..."
      sleep 2
      
      # Create the post
      puts "📝 Creating post..."
      post_data = create_post(media_ids)
      
      # Return URLs
      build_result(post_data)
    end
    
    private
    
    def upload_media(path, description = nil)
      uri = URI("#{@instance_url}/api/v1/media")
      
      # Log file info for debugging
      file_size = File.size(path)
      file_type = mime_type(path)
      puts "    File: #{File.basename(path)} (#{file_size} bytes, #{file_type})"
      
      File.open(path, 'rb') do |file|
        req = Net::HTTP::Post::Multipart.new(uri.path,
          'file' => UploadIO.new(file, file_type, File.basename(path)),
          'description' => description || ''
        )
        req['Authorization'] = "Bearer #{@access_token}"
        
        response = make_request(uri, req)
        data = JSON.parse(response.body)
        
        if response.code != '200'
          raise "Media upload failed: #{data['error'] || response.message}"
        end
        
        # Log the returned media info
        puts "    Media ID: #{data['id']}"
        puts "    Preview URL: #{data['preview_url']}" if data['preview_url']
        puts "    URL: #{data['url']}" if data['url']
        
        data['id']
      end
    end
    
    def create_post(media_ids)
      uri = URI("#{@instance_url}/api/v1/statuses")
      
      status_text = @post_text
      status_text += "\n\n" + @tags.join(' ') unless @tags.empty?
      
      params = {
        'status' => status_text,
        'media_ids' => media_ids,
        'visibility' => @visibility
      }
      
      req = Net::HTTP::Post.new(uri.path)
      req['Authorization'] = "Bearer #{@access_token}"
      req['Content-Type'] = 'application/json'
      req.body = params.to_json
      
      response = make_request(uri, req)
      data = JSON.parse(response.body)
      
      if response.code != '200'
        raise "Post creation failed: #{data['error'] || response.message}"
      end
      
      # Log media attachment info
      if data['media_attachments']
        puts "\n📎 Media attachments in post:"
        data['media_attachments'].each do |att|
          puts "  - Type: #{att['type']}, URL: #{att['url']}"
          puts "    Preview: #{att['preview_url']}" if att['preview_url']
        end
      end
      
      data
    end
    
    def make_request(uri, req)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.request(req)
    end
    
    def mime_type(path)
      case File.extname(path).downcase
      when '.jpg', '.jpeg' then 'image/jpeg'
      when '.png' then 'image/png'
      when '.gif' then 'image/gif'
      when '.webp' then 'image/webp'
      else 'application/octet-stream'
      end
    end
    
    def build_result(post_data)
      post_url = post_data['url']
      
      {
        url: post_url,
        markdown: "[View post on GoToSocial](#{post_url})",
        html: %(<a href="#{post_url}">View post on GoToSocial</a>),
        org: "[[#{post_url}][View post on GoToSocial]]"
      }
    end
  end
end

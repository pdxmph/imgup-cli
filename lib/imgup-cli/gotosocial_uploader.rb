# lib/imgup-cli/gotosocial_uploader.rb
require 'net/http'
require 'uri'
require 'json'
require 'net/http/post/multipart'
require 'mini_magick'
require 'fileutils'
require_relative 'config'

module ImgupCli
  class GotosocialUploader
    MAX_IMAGES = 4  # Mastodon API limit
    
    def initialize(path = nil, images: [], post_text: nil, tags: [], visibility: 'public', resize: nil, **_opts)
      @images = images
      @post_text = post_text || ''
      @tags = Array(tags).map { |t| "##{t.gsub(/[^a-zA-Z0-9]/, '')}" }
      @visibility = visibility
      @resize = resize
      
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
      
      # Resize image if requested
      upload_path = path
      if @resize
        upload_path = resize_image(path)
      end
      
      # Log file info for debugging
      file_size = File.size(upload_path)
      file_type = mime_type(upload_path)
      puts "    File: #{File.basename(upload_path)} (#{file_size} bytes, #{file_type})"
      puts "    Resized from #{File.size(path)} bytes" if upload_path != path
      
      File.open(upload_path, 'rb') do |file|
        req = Net::HTTP::Post::Multipart.new(uri.path,
          'file' => UploadIO.new(file, file_type, File.basename(upload_path)),
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
        
        # Clean up temp file if we resized
        FileUtils.rm_f(upload_path) if upload_path != path
        
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
    
    def resize_image(path)
      # Parse resize dimensions (e.g., "1920x1920", "1200x", "x800")
      dimensions = @resize.split('x').map { |d| d.empty? ? nil : d.to_i }
      width = dimensions[0]
      height = dimensions[1]
      
      # Create temp file path
      temp_dir = File.join(Dir.tmpdir, 'imgup-resize')
      FileUtils.mkdir_p(temp_dir)
      temp_path = File.join(temp_dir, "resized_#{File.basename(path)}")
      
      # Resize image
      image = MiniMagick::Image.open(path)
      
      # Get original dimensions
      orig_width = image.width
      orig_height = image.height
      puts "    Original: #{orig_width}x#{orig_height}"
      
      # Only resize if image is larger than target
      if width && height
        # Fit within box while maintaining aspect ratio
        if orig_width > width || orig_height > height
          image.resize "#{width}x#{height}>"
          puts "    Resizing to fit within #{width}x#{height}"
        end
      elsif width
        # Resize width, maintain aspect ratio
        if orig_width > width
          image.resize "#{width}x"
          puts "    Resizing width to #{width}px"
        end
      elsif height
        # Resize height, maintain aspect ratio  
        if orig_height > height
          image.resize "x#{height}"
          puts "    Resizing height to #{height}px"
        end
      end
      
      # Optimize for web (strip metadata, optimize compression)
      image.strip
      image.quality 85 if mime_type(path) == 'image/jpeg'
      
      # Save resized image
      image.write temp_path
      
      temp_path
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

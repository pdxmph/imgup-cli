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
    
    def initialize(path = nil, images: [], post_text: nil, tags: [], visibility: 'public', resize: nil, verbose: false, **_opts)
      @images = images
      @post_text = post_text || ''
      @tags = Array(tags).map { |t| "##{t.gsub(/[^a-zA-Z0-9]/, '')}" }
      @visibility = visibility
      @resize = resize
      @verbose = verbose
      
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
      if @verbose
        puts "⏳ Waiting for image processing..."
      end
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
      was_resized = false
      if @resize
        resized_path = resize_image(path)
        if resized_path != path
          upload_path = resized_path
          was_resized = true
        end
      end
      
      # Log file info for debugging
      file_size = File.size(upload_path)
      file_type = mime_type(upload_path)
      if @verbose
        puts "    File: #{File.basename(upload_path)} (#{file_size} bytes, #{file_type})"
        puts "    Resized from #{File.size(path)} bytes" if was_resized
      end
      
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
        if @verbose
          puts "    Media ID: #{data['id']}"
          puts "    Preview URL: #{data['preview_url']}" if data['preview_url']
          puts "    URL: #{data['url']}" if data['url']
        end
        
        # Clean up temp file if we resized
        FileUtils.rm_f(upload_path) if was_resized
        
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
      if @verbose && data['media_attachments']
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
      dimensions = @resize.split('x')
      
      # Handle width
      if dimensions[0] && !dimensions[0].empty?
        width = dimensions[0].to_i
      else
        width = nil
      end
      
      # Handle height - check if array has second element
      if dimensions.length > 1 && dimensions[1] && !dimensions[1].empty?
        height = dimensions[1].to_i
      else
        height = nil
      end
      
      # Debug output
      if @verbose
        puts "    Resize request: '#{@resize}' -> width: #{width.inspect}, height: #{height.inspect}"
      end
      
      # Create temp file path
      temp_dir = File.join(Dir.tmpdir, 'imgup-resize')
      FileUtils.mkdir_p(temp_dir)
      temp_path = File.join(temp_dir, "resized_#{File.basename(path)}")
      
      # Open and process image
      MiniMagick::Tool::Convert.new do |convert|
        convert << path
        convert.auto_orient
        convert.strip
        
        # Get original dimensions for logging
        image = MiniMagick::Image.open(path)
        orig_width = image.width
        orig_height = image.height
        if @verbose
          puts "    Original: #{orig_width}x#{orig_height}"
        end
        
        # Apply resize based on options
        if width && height
          # Fit within box while maintaining aspect ratio
          if orig_width > width || orig_height > height
            convert.resize "#{width}x#{height}>"
            puts "    Resizing to fit within #{width}x#{height}" if @verbose
          else
            puts "    No resize needed" if @verbose
            return path
          end
        elsif width && !height
          # Resize width, maintain aspect ratio
          if orig_width > width
            convert.resize "#{width}x>"
            puts "    Resizing width to max #{width}px" if @verbose
          else
            puts "    No resize needed" if @verbose
            return path
          end
        elsif height && !width
          # Resize height, maintain aspect ratio  
          if orig_height > height
            convert.resize "x#{height}>"
            puts "    Resizing height to max #{height}px" if @verbose
          else
            puts "    No resize needed" if @verbose
            return path
          end
        else
          puts "    Invalid resize dimensions" if @verbose
          return path
        end
        
        # Set quality for JPEG
        if mime_type(path) == 'image/jpeg'
          convert.quality "85"
        end
        
        convert << temp_path
      end
      
      # Verify the output
      if File.exist?(temp_path) && File.size(temp_path) > 1000
        resized_size = File.size(temp_path)
        puts "    Resized file: #{resized_size} bytes" if @verbose
        temp_path
      else
        puts "    ERROR: Resize failed, using original" if @verbose
        path
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

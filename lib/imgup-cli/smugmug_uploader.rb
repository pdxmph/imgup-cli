# lib/imgup-cli/smugmug_uploader.rb
require 'fileutils'
require 'net/http'
require 'uri'
require 'json'
require 'oauth'
require 'oauth/client/net_http'
require 'net/http/post/multipart'
require_relative 'config'

module ImgupCli
  class SmugMugUploader
    API_BASE   = 'https://api.smugmug.com'
    UPLOAD_URL = 'https://upload.smugmug.com/'

    def initialize(path, title:, caption:, tags: [])
      @path    = path
      @title   = title    || File.basename(path, '.*')
      @caption = caption  || ''
      @tags    = Array(tags).map(&:strip)

      cfg = Config.load
      @consumer_key        = cfg['consumer_key']
      @consumer_secret     = cfg['consumer_secret']
      @access_token        = cfg['access_token']
      @access_token_secret = cfg['access_token_secret']
      @album_id            = cfg['album_id'] || abort("❌ No album_id in config; run `imgup setup` first.")

      consumer = OAuth::Consumer.new(@consumer_key, @consumer_secret, site: API_BASE)
      @access  = OAuth::AccessToken.new(consumer, @access_token, @access_token_secret)
    end

    # Uploads the file and returns the standard snippet hashes.
    def call
      tmp      = copy_to_tmp
      image    = upload_file(tmp)
      cleanup_tmp(tmp)
      full_url = fetch_full_url(image)
      build_result(full_url)
    end

    private

    def copy_to_tmp
      FileUtils.mkdir_p('tmp')
      tmp = File.join('tmp', File.basename(@path))
      FileUtils.cp(@path, tmp)
      tmp
    end

    def upload_file(tmp_path)
      uri     = URI(UPLOAD_URL)
      file_io = UploadIO.new(File.open(tmp_path), 'application/octet-stream', File.basename(tmp_path))
      req     = Net::HTTP::Post::Multipart.new(uri.request_uri, 'file' => file_io)

      # Required SmugMug headers
      req['X-Smug-AlbumUri']     = "/api/v2/album/#{@album_id}"
      req['X-Smug-ResponseType'] = 'JSON'
      req['X-Smug-Version']      = 'v2'
      req['X-Smug-Filename']     = File.basename(tmp_path)
      req['X-Smug-Title']        = @title
      req['X-Smug-Caption']      = @caption
      # ← Just one new line to support tags:
      req['X-Smug-Keywords']     = @tags.join(',') unless @tags.empty?

      # Sign and send the multipart request
      upload_consumer = OAuth::Consumer.new(
        @consumer_key,
        @consumer_secret,
        site: "#{uri.scheme}://#{uri.host}"
      )
      upload_access = OAuth::AccessToken.new(
        upload_consumer,
        @access_token,
        @access_token_secret
      )
      upload_access.sign! req

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      resp = http.request(req)

      unless resp.is_a?(Net::HTTPSuccess)
        raise "Upload failed: HTTP #{resp.code} #{resp.message}; Body: #{resp.body}"
      end

      JSON.parse(resp.body)['Image']
    end

    def fetch_full_url(image)
      image_uri = image['ImageUri'] || image['Uri']
      raise "No ImageUri found in upload response: #{image.inspect}" unless image_uri

      uri = URI.join(API_BASE, "#{image_uri}!sizes")
      req = Net::HTTP::Get.new(uri.request_uri)
      req['Accept'] = 'application/json'
      @access.sign! req

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      resp = http.request(req)
      raise "Size-fetch failed: HTTP #{resp.code} #{resp.message}" unless resp.is_a?(Net::HTTPSuccess)

      data  = JSON.parse(resp.body)
      sizes = data.dig('Response', 'ImageSizes', 'Size')
      if sizes.is_a?(Array) && sizes.any?
        sizes.max_by { |s| s['Width'].to_i }['Url']
      else
        h = data.dig('Response','ImageSizes')
        %w[XLargeImageUrl LargestImageUrl OriginalImageUrl].each { |k| return h[k] if h[k] }
        raise "No image size URL found: #{data.inspect}"
      end
    end

    def cleanup_tmp(path)
      FileUtils.rm_f(path)
    end

    def build_result(full_url)
      {
        url:      full_url,
        markdown: "![#{@title}](#{full_url})",
        html:     "<img src=\"#{full_url}\" alt=\"#{@title}\" />",
        org:      "[[img:#{full_url}][#{@title}]]"
      }
    end
  end
end

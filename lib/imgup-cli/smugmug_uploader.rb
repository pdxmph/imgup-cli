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
    def initialize(filepath, title:, caption:)
      @filepath = filepath
      @title    = title || File.basename(filepath, '.*')
      @caption  = caption || ''
      load_env
      setup_oauth_client
    end

    # Executes the upload and returns a hash of snippets:
    # { url: ..., markdown: ..., html: ..., org: ... }
    def call
      tmp      = copy_to_tmp
      image    = upload_file(tmp)
      cleanup_tmp(tmp)
      full_url = fetch_full_url(image)
      build_result(full_url)
    end

    private

    def load_env
      cfg = Config.load
      @consumer_key        = ENV['SMUGMUG_TOKEN']               || cfg['consumer_key']
      @consumer_secret     = ENV['SMUGMUG_SECRET']              || cfg['consumer_secret']
      @access_token        = ENV['SMUGMUG_ACCESS_TOKEN']        || cfg['access_token']
      @access_token_secret = ENV['SMUGMUG_ACCESS_TOKEN_SECRET'] || cfg['access_token_secret']
      @album_id            = ENV['SMUGMUG_UPLOAD_ALBUM_ID']      || cfg['album_id']
      @upload_url          = ENV['SMUGMUG_UPLOAD_URL']          || 'https://upload.smugmug.com/'
      @api_base            = ENV['SMUGMUG_API_URL']             || 'https://api.smugmug.com'
    end

    def setup_oauth_client
      @consumer = OAuth::Consumer.new(
        @consumer_key,
        @consumer_secret,
        site: @api_base
      )
      @access = OAuth::AccessToken.new(
        @consumer,
        @access_token,
        @access_token_secret
      )
    end

    def copy_to_tmp
      FileUtils.mkdir_p('tmp')
      tmp = File.join('tmp', File.basename(@filepath))
      FileUtils.cp(@filepath, tmp)
      tmp
    end

    def upload_file(tmp_path)
      uri     = URI(@upload_url)
      file_io = UploadIO.new(File.open(tmp_path), 'application/octet-stream', File.basename(tmp_path))
      req     = Net::HTTP::Post::Multipart.new(uri.request_uri, 'file' => file_io)

      # SmugMug-specific headers
      {
        'X-Smug-AlbumUri'     => "/api/v2/album/#{@album_id}",
        'X-Smug-ResponseType' => 'JSON',
        'X-Smug-Version'      => 'v2',
        'X-Smug-Filename'     => File.basename(tmp_path),
        'X-Smug-Title'        => @title,
        'X-Smug-Caption'      => @caption
      }.each { |k, v| req[k] = v }

      # Sign with OAuth
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
      http.use_ssl = (uri.scheme == 'https')
      resp = http.request(req)

      unless resp.is_a?(Net::HTTPSuccess)
        raise "Upload failed: HTTP #{resp.code} #{resp.message}; Body: #{resp.body}"
      end

      JSON.parse(resp.body)['Image']
    end

    def fetch_full_url(image)
      image_uri = image['ImageUri'] || image['Uri']
      raise "No ImageUri found in upload response: #{image.inspect}" unless image_uri

      uri = URI.join(@api_base, "#{image_uri}!sizes")
      req = Net::HTTP::Get.new(uri.request_uri)
      req['Accept'] = 'application/json'
      @access.sign! req

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      resp = http.request(req)
      unless resp.is_a?(Net::HTTPSuccess)
        raise "Size-fetch failed: HTTP #{resp.code} #{resp.message}"
      end

      body  = JSON.parse(resp.body)
      sizes = body.dig('Response', 'ImageSizes', 'Size')
      if sizes.is_a?(Array) && sizes.any?
        best = sizes.max_by { |s| s['Width'].to_i }
        return best['Url']
      end

      sizes_hash = body.dig('Response', 'ImageSizes')
      %w[XLargeImageUrl LargestImageUrl OriginalImageUrl].each do |key|
        return sizes_hash[key] if sizes_hash[key]
      end

      raise "No image size URL found in size response: #{body.inspect}"
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

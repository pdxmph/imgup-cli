# lib/imgup-cli/flickr_uploader.rb
require 'flickraw'
require_relative 'config'

module ImgupCli
  class FlickrUploader
    def initialize(path, title:, caption:)
      @path    = path
      @title   = title || File.basename(path, '.*')
      @caption = caption.to_s

      creds = Config.load
      FlickRaw.api_key       = ENV['FLICKR_KEY']    || creds['flickr_key']
      FlickRaw.shared_secret = ENV['FLICKR_SECRET'] || creds['flickr_secret']

      @flickr = FlickRaw::Flickr.new
      @flickr.access_token  = creds['flickr_access_token']
      @flickr.access_secret = creds['flickr_access_token_secret']
    end

    def call
      # Upload the photo
      photo_id = @flickr.upload_photo(
        @path,
        title:       @title,
        description: @caption
      )

      # Fetch info for the uploaded photo
      info = @flickr.photos.getInfo(photo_id: photo_id)

      # Build a URL (size 'b' = large)
      url = FlickRaw.url_b(info)

      # Return all snippet formats
      {
        url:      url,
        markdown: "![#{@title}](#{url})",
        html:     "<img src=\"#{url}\" alt=\"#{@title}\">",
        org:      "[[img:#{url}][#{@title}]]"
      }
    end
  end
end

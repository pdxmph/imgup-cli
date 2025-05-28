require 'flickraw'
require_relative 'config'

module ImgupCli
  # Handles upload to Flickr, now with tag support.
  class FlickrUploader
    def initialize(path, title:, caption:, alt_text:, tags: [])
      @path     = path
      @title    = title || File.basename(path, '.*')
      @caption  = caption.to_s
      @alt_text = alt_text || @caption || ''
      @tags     = Array(tags).map(&:strip)

      creds = Config.load
      FlickRaw.api_key       = creds['flickr_key']
      FlickRaw.shared_secret = creds['flickr_secret']

      @flickr = FlickRaw::Flickr.new
      @flickr.access_token  = creds['flickr_access_token']
      @flickr.access_secret = creds['flickr_access_token_secret']
    end

    def call
      # Upload with tags (space‐separated)
      photo_id = @flickr.upload_photo(
        @path,
        title:       @title,
        description: @caption,
        tags:        @tags.join(' ')
      )

      info = @flickr.photos.getInfo(photo_id: photo_id)
      url  = FlickRaw.url_b(info)

      {
        url:      url,
        markdown: "![#{@alt_text}](#{url})",
        html:     "<img src=\"#{url}\" alt=\"#{@alt_text}\">",
        org:      "[[img:#{url}][#{@alt_text}]]",
        # Additional data for social media integration
        image_url: url,
        title: @title,
        caption: @caption,
        alt_text: @alt_text,
        tags: @tags
      }
    end
  end
end

require 'flickraw'
require_relative 'config'

module ImgupCli
  class FlickrUploader
    def initialize(path, title:, caption:)
      @path    = path
      @title   = title || File.basename(path, '.*')
      @caption = caption

      creds = Config.load
      FlickRaw.api_key       = ENV['FLICKR_KEY']    || creds['flickr_key']
      FlickRaw.shared_secret = ENV['FLICKR_SECRET'] || creds['flickr_secret']

      @flickr = FlickRaw::Flickr.new
      @flickr.access_token  = creds['flickr_access_token']
      @flickr.access_secret = creds['flickr_access_token_secret']
    end

    def call
      photo_id = @flickr.upload_photo(
        @path,
        title:       @title,
        description: @caption
      )
      info = @flickr.photos.getInfo(photo_id: photo_id)
      url  = FlickRaw.url_b(info)  # or whatever size you prefer

      {
        markdown: "![#{@title}](#{url})",
        org:       url,
        html:      "<img src=\"#{url}\" alt=\"#{@title}\">"
      }
    end
  end
end

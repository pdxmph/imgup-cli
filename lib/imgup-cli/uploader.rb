require_relative 'smugmug_uploader'
require_relative 'flickr_uploader'

module ImgupCli
  class Uploader
    def self.build(backend, path, title:, caption:)
      case backend
      when 'smugmug' then SmugMugUploader.new(path, title: title, caption: caption)
      when 'flickr'  then FlickrUploader.new(path, title: title, caption: caption)
      else
        raise ArgumentError, "Unknown backend: #{backend.inspect}"
      end
    end
  end
end

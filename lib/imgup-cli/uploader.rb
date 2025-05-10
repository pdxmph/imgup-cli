# lib/imgup-cli/uploader.rb
require_relative 'smugmug_uploader'
require_relative 'flickr_uploader'

module ImgupCli
  # Uploader factory: builds the right backend client,
  # forwarding title, caption, and tags.
  class Uploader
    # Build an uploader for the given backend.
    #
    # @param backend [String] 'smugmug' or 'flickr'
    # @param path    [String] path to local file
    # @param title   [String, nil]
    # @param caption [String, nil]
    # @param tags    [Array<String>] list of tag strings
    # @return [SmugMugUploader,FlickrUploader]
    def self.build(backend, path, title:, caption:, tags: [])
      case backend.to_s.downcase
      when 'smugmug'
        SmugMugUploader.new(path, title: title, caption: caption, tags: tags)
      when 'flickr'
        FlickrUploader.new(path, title: title, caption: caption, tags: tags)
      else
        raise ArgumentError, "Unknown backend: #{backend.inspect}"
      end
    end
  end
end

# lib/imgup-cli/metadata_extractor.rb
require 'exifr/jpeg'
require 'xmp'

module ImgupCli
  class MetadataExtractor
    attr_reader :path

    def initialize(path)
      @path = path
      @exif = nil
      @xmp = nil
      
      # Try to load EXIF data
      begin
        @exif = EXIFR::JPEG.new(path) if path.downcase.end_with?('.jpg', '.jpeg')
      rescue => e
        # Silent fail - not all images have EXIF
      end
      
      # Try to load XMP data
      begin
        # The XMP gem needs a file path, not content
        @xmp = XMP.parse(File.open(path))
      rescue => e
        # Silent fail - not all images have XMP
      end
    end

    def extract
      {
        alt_text: extract_alt_text,
        title: extract_title,
        caption: extract_caption,
        tags: extract_tags
      }
    end

    private

    def extract_alt_text
      # Priority: IPTC Caption-Abstract → XMP description → filename
      # EXIFR provides image_description which maps to IPTC Caption-Abstract
      alt = nil
      
      # Try EXIF/IPTC first
      alt ||= @exif.image_description if @exif&.image_description
      
      # Try XMP description
      if @xmp && !alt
        begin
          alt ||= @xmp.dc.description.first if @xmp.dc&.description
        rescue
          # XMP structure can vary
        end
      end
      
      # Fallback to filename without extension
      alt || File.basename(@path, '.*')
    end

    def extract_title
      # Priority: IPTC ObjectName → EXIF DocumentName → filename
      title = nil
      
      # Try EXIF fields
      if @exif
        title ||= @exif.document_name if @exif.respond_to?(:document_name)
        title ||= @exif.title if @exif.respond_to?(:title)
      end
      
      # Try XMP title
      if @xmp && !title
        begin
          if @xmp.dc&.title
            # XMP title can be a simple string or an array
            title = case @xmp.dc.title
                    when Array
                      @xmp.dc.title.first
                    when String
                      @xmp.dc.title
                    else
                      # Handle rdf:Alt structure - try to get the value
                      @xmp.dc.title.to_s if @xmp.dc.title.respond_to?(:to_s)
                    end
          end
        rescue
          # XMP structure can vary
        end
      end
      
      # Fallback to filename without extension
      title || File.basename(@path, '.*')
    end

    def extract_caption
      # For now, caption follows the same logic as alt_text
      # This gives us flexibility to change the behavior later
      extract_alt_text
    end

    def extract_tags
      keywords = []
      
      # Extract from EXIF
      if @exif
        if @exif.respond_to?(:keywords)
          kw = @exif.keywords
          # Handle both string and array returns
          keywords += (kw.is_a?(String) ? kw.split(/[,;]\s*/) : Array(kw))
        end
      end
      
      # Extract from XMP
      if @xmp
        begin
          if @xmp.dc&.subject
            keywords += Array(@xmp.dc.subject)
          end
        rescue
          # XMP structure can vary
        end
      end
      
      # Clean up and deduplicate
      keywords.map(&:to_s).map(&:strip).reject(&:empty?).uniq
    end
  end
end

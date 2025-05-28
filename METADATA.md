# Metadata Extraction in imgup-cli

As of the `feature/proper-metadata` branch, imgup-cli now properly handles image metadata extraction and separates the concepts of title and alt text.

## What's New

### Automatic Metadata Extraction

By default, imgup-cli now extracts metadata from your images:

- **Alt Text**: IPTC Caption-Abstract → XMP description → filename
- **Title**: IPTC ObjectName → EXIF DocumentName → filename  
- **Tags/Keywords**: IPTC Keywords + XMP subject fields

### New Command Line Options

```bash
# Explicitly set alt text (overrides extraction)
imgup --alt-text "Descriptive text for accessibility" image.jpg

# Disable automatic metadata extraction
imgup --no-extract image.jpg

# Review and edit metadata before upload
imgup --review image.jpg

# See what metadata was extracted
imgup --verbose image.jpg
```

## Metadata Field Mapping

| imgup Field | EXIF/IPTC Source | Usage |
|-------------|------------------|-------|
| alt_text | IPTC Caption-Abstract, XMP-dc:description | Used in HTML alt attribute, social media descriptions |
| title | IPTC ObjectName, EXIF DocumentName | Display title on SmugMug/Flickr |
| caption | Same as alt_text | SmugMug caption field |
| tags | IPTC Keywords, XMP-dc:subject | Tags on SmugMug/Flickr |

## Examples

### Basic Usage (with auto-extraction)
```bash
# Upload with metadata extracted from the image
imgup photo.jpg
```

### Review Before Upload
```bash
# See and edit metadata before uploading
imgup --review photo.jpg
```

### Override Extracted Metadata
```bash
# Use your own alt text instead of extracted caption
imgup --alt-text "Sunset over Pacific Ocean" --title "California Sunset" photo.jpg
```

### Integration with Photo Workflows

When using Lightroom CC or Apple Photos:
1. Add your caption/description in the app
2. Export with metadata embedded
3. imgup will automatically use that metadata

The updated Hazel script (`extras/hazel_smugmug_v2.sh`) now relies on imgup's built-in extraction instead of calling exiftool separately.

## Backward Compatibility

All existing commands continue to work:
- `--title` and `--caption` options override extracted metadata
- If you don't want extraction, use `--no-extract`
- The output formats (markdown, HTML, org) remain the same

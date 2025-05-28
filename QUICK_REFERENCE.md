# imgup-cli Metadata Quick Reference

## New Options

```bash
--alt-text TEXT     # Set alt text for accessibility (overrides extraction)
--no-extract        # Disable automatic metadata extraction
--review           # Review/edit metadata before upload
```

## Metadata Priority

**Alt Text**: `--alt-text` → IPTC Caption → XMP description → filename  
**Title**: `--title` → IPTC ObjectName → EXIF DocumentName → filename  
**Tags**: `--tags` → IPTC Keywords + XMP subject

## Examples

```bash
# Let imgup extract metadata from photo
imgup photo.jpg

# See what will be extracted
imgup --verbose --review photo.jpg

# Override with your own alt text
imgup --alt-text "Descriptive text" photo.jpg

# Skip extraction, use only command line options
imgup --no-extract --title "My Title" --alt-text "My description" photo.jpg

# Post to Mastodon with proper accessibility
imgup --mastodon --alt-text "Clear description of image" photo.jpg
```

## Photo Editor → imgup Mapping

| Editor Field | → | imgup extracts as |
|-------------|---|-------------------|
| Caption/Description | → | alt_text |
| Title/Object Name | → | title |
| Keywords | → | tags |

## Snippet Output

- **HTML**: `<img src="..." alt="[alt_text]" />`
- **Markdown**: `![alt_text](url)`
- **Org**: `[[img:url][alt_text]]`

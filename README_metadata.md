# imgup-cli Metadata: Complete Workflow Guide

This guide shows how metadata flows from your photo editor through imgup-cli to your final output.

## Table of Contents
- [Quick Reference](#quick-reference)
- [Setting Metadata in Photo Editors](#setting-metadata-in-photo-editors)
- [How Metadata Appears on Services](#how-metadata-appears-on-services)
- [Snippet Output Examples](#snippet-output-examples)
- [Social Media Posts](#social-media-posts)
- [Testing Your Workflow](#testing-your-workflow)

## Quick Reference

| imgup Option | Photo Editor Field | SmugMug | Flickr | HTML/MD/Org | Social Media |
|--------------|-------------------|----------|---------|-------------|--------------|
| `--alt-text` | Caption/Description | (stored) | (stored) | alt="..." | Image description |
| `--title` | Title/Name | Image Title | Photo Title | (not shown) | (not used) |
| `--caption` | Caption/Description | Caption field | Description | (not shown) | Fallback for alt |
| `--tags` | Keywords | Keywords | Tags | (not shown) | Hashtags in post |

## Setting Metadata in Photo Editors

### Lightroom Classic/CC

Set these fields in the Library module's Metadata panel:

```
Title         → "Golden Gate at Sunset"     → imgup extracts as title
Caption       → "The Golden Gate Bridge..."  → imgup extracts as alt_text/caption
Keywords      → bridge, sunset, california   → imgup extracts as tags
```

**Export Settings:**
- ✅ Include: All Metadata
- ✅ Write Keywords as Lightroom Hierarchy

### Apple Photos ✅

Set these fields in the Info panel (⌘I):

```
Title         → "Golden Gate at Sunset"     → imgup extracts as title
Description   → "The Golden Gate Bridge..."  → imgup extracts as alt_text/caption
Keywords      → bridge, sunset, california   → imgup extracts as tags
```

**Export Settings:**
- Choose: JPEG - High Quality
- ✅ Include: Title, Keywords, Description, and Location Info

**Note**: Apple Photos writes metadata to XMP fields which imgup now properly reads.
### Capture One

Set in the Metadata tool:

```
Object Name   → "Golden Gate at Sunset"     → imgup extracts as title
Description   → "The Golden Gate Bridge..."  → imgup extracts as alt_text/caption
Keywords      → bridge, sunset, california   → imgup extracts as tags
```

## How Metadata Appears on Services

### SmugMug Display

```bash
imgup --title "Sunset Photo" --alt-text "Golden Gate Bridge at sunset" --tags "bridge,sunset" photo.jpg
```

**Result on SmugMug:**
- Gallery thumbnail caption: "Sunset Photo"
- Image page title: "Sunset Photo"
- Keywords: bridge, sunset (searchable)
- Alt text: Stored but not displayed (used when sharing)

### Flickr Display

```bash
imgup --backend flickr --title "Sunset Photo" --alt-text "Golden Gate Bridge at sunset" --tags "bridge,sunset" photo.jpg
```

**Result on Flickr:**
- Photo title: "Sunset Photo"
- Description: "Golden Gate Bridge at sunset"
- Tags: bridge sunset (clickable)

## Snippet Output Examples

### Example Image with Metadata

```bash
# Using extracted metadata
imgup photo.jpg  # Has IPTC caption "Beautiful sunset over the bay"

# Or explicit metadata
imgup --alt-text "Beautiful sunset over the bay" --title "Sunset" photo.jpg
```

### HTML Output (`--format html`)

```html
<img src="https://photos.smugmug.com/..." alt="Beautiful sunset over the bay" />
```

**What each field does:**
- `alt` attribute: Uses `--alt-text` (or extracted caption)
- No title attribute added
- URL: The SmugMug/Flickr image URL
### Markdown Output (`--format md`)

```markdown
![Beautiful sunset over the bay](https://photos.smugmug.com/...)
```

**What each field does:**
- Alt text in brackets: Uses `--alt-text` (or extracted caption)
- URL in parentheses: The SmugMug/Flickr image URL

### Org-mode Output (`--format org`)

```org
[[img:https://photos.smugmug.com/...][Beautiful sunset over the bay]]
```

**What each field does:**
- Link text: Uses `--alt-text` (or extracted caption)
- Custom link type `img:` for proper export

## Social Media Posts

### Mastodon/GoToSocial Posting

```bash
imgup --mastodon --post "Check out this sunset!" --tags "photography,sunset" photo.jpg
```

**Result on Mastodon:**
```
Check out this sunset!

#photography #sunset

[Image attachment]
```

**Image attachment details:**
- Description field: Uses `--alt-text` (or extracted caption)
- This appears when users hover or use screen readers

### Field Priority for Social Media

The image description uses this priority:
1. `--alt-text` (if specified)
2. Extracted IPTC Caption-Abstract
3. Extracted XMP description
4. `--caption` (if specified)
5. `--title` (if specified)
6. Filename (last resort)
## Testing Your Workflow

### Test 1: Verify Metadata Extraction

```bash
# See what imgup extracts from your photo
imgup --verbose --review photo.jpg
```

Expected output:
```
Extracted metadata from image:
  Alt text: The Golden Gate Bridge glowing in sunset light
  Title: Golden Gate at Sunset
  Tags: bridge, sunset, california

Metadata for upload:
  Title: Golden Gate at Sunset
  Alt text: The Golden Gate Bridge glowing in sunset light
  Caption: The Golden Gate Bridge glowing in sunset light
  Tags: bridge, sunset, california

Proceed with upload? (y/n/e[dit]):
```

### Test 2: Check Alt Text in Output

```bash
# Generate snippet without uploading (requires setup)
imgup --backend smugmug photo.jpg | head -1
```

Should produce:
```
![The Golden Gate Bridge glowing in sunset light](https://photos.smugmug.com/...)
```

### Test 3: Verify Social Media Description

```bash
# Test with explicit alt text
imgup --mastodon --alt-text "Descriptive text for accessibility" \
      --post "My photo" photo.jpg
```

The uploaded image on Mastodon will have "Descriptive text for accessibility" as its description.

### Test 4: Override Extraction

```bash
# Your photo has IPTC caption "Original caption"
# But you want different alt text:
imgup --alt-text "Better description for web" photo.jpg
```

Output will use "Better description for web" instead of "Original caption".
## Common Scenarios

### Scenario 1: Photo from Lightroom

You export from Lightroom with:
- Title: "Yosemite Valley"
- Caption: "Half Dome rises above Yosemite Valley in late afternoon light"
- Keywords: yosemite, halfdome, landscape

```bash
imgup photo.jpg --verbose
```

Result:
- SmugMug title: "Yosemite Valley"
- HTML snippet: `<img src="..." alt="Half Dome rises above Yosemite Valley in late afternoon light" />`
- Tags on service: yosemite, halfdome, landscape

### Scenario 2: Quick Phone Photo

Photo has no metadata, just filename "IMG_1234.jpg"

```bash
imgup --alt-text "My cat sleeping on the couch" --title "Nap Time" IMG_1234.jpg
```

Result:
- SmugMug title: "Nap Time"
- HTML snippet: `<img src="..." alt="My cat sleeping on the couch" />`

### Scenario 3: Social Media with Accessibility

```bash
imgup --mastodon --alt-text "A red-tailed hawk perched on a fence post" \
      --post "Spotted this beautiful hawk on my walk today!" \
      --tags "birds,nature,photography" hawk.jpg
```

Mastodon post shows:
- Post text: "Spotted this beautiful hawk on my walk today! #birds #nature #photography"
- Image has description: "A red-tailed hawk perched on a fence post"

## Troubleshooting

**"Warning: Could not extract metadata"**
- File might not be JPEG (EXIF only works with JPEG)
- Use `--verbose` to see detailed error

**Alt text not showing in snippet**
- Check extraction worked: `imgup --verbose --review photo.jpg`
- Override with explicit: `imgup --alt-text "Your text" photo.jpg`

**Wrong metadata extracted**
- Use `--no-extract` to disable automatic extraction
- Set fields explicitly with command line options
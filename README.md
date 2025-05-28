# imgup: Smugmug and flickr uploads from the command line

## Description 
Provides a command line uploader to SmugMug and/or flickr that returns snippets in HTML, org-mode, or Markdown suitable for pasting into a blog post. Optionally creates posts of those images to Mastodon and/or gotosocial. 

## Reason for existence
If you're all in on SmugMug or flickr and would prefer their higher-quality image embeds over what your own blogging provider might do, or if you move blogging tools around a lot and don't want to manage the media assets, this is a quick way to get usable markup you can drop into a blogpost. If you prefer to share the image over social media, there are options to add it to a post for Mastodon or gotosocial. 

## SmugMug Setup

There's a mildly janky setup involved due to my own issues understanding how to get a PIN back. Pay close attention to the prompts and copy the entire callback URL when asked. 

1. [Get an API key from SmugMug][smkey]. 
2. Have your key and secret handy
3. Install the gem
4. run `imgup setup`
5. When prompted, provide your API key and secret
6. Your browser will open to auth SmugMug. 
7. Your browser will redirect (and 404), copy the _entire_ URL from the browser location
8. Paste the URL into the CLI
9. Select a target album

Should be ready to go at that point. See "Usage" below.

## Flickr Setup

1. [Get an API key from flickr][fkey]. 
2. Grab your key and secret. 
3. install the gem
4. run `imgup setup flickr`
5. Answer the prompts for key and secret
6. Authenticate with your browser. 

Should be ready to go at that point. See "Usage" below.

## Mastodon Setup

1. Go to your Mastodon instance's `/settings/applications`
2. Create a new application
3. Copy the access token
4. Run `imgup setup mastodon`
5. Paste your instance URL and token

Should be ready to go at that point. See "Usage" below.

## GoToSocial Setup

1. Go to your GoToSocial instance
2. Settings → Applications → New Application
3. Run `imgup setup gotosocial`
4. Provide your instance URL and credentials

Should be ready to go at that point. See "Usage" below.

## Usage 

`imgup` takes a few arguments:

### Basic Options
- `--title, -t` - To set the image title, for purposes of display on flickr or SmugMug
- `--caption, -c` - To set the caption, which will act as the alt text/description
- `--alt-text` - Explicitly set alt text for accessibility (overrides caption)
- `--backend, -b` - To set the backend, i.e. `smugmug` or `flickr`
- `--format, -f` - To set the format of the snippet (org, md, or html)
- `--tags` - Comma-separated tags
- `--verbose, -v` - Enable verbose output for debugging

### Metadata Options
- `--review` - Review and edit metadata before upload
- `--no-extract` - Disable automatic metadata extraction from images

**Note**: imgup automatically extracts metadata from your images (title, description, keywords) if available in EXIF/IPTC/XMP fields.

### Social Posting Options
- `--mastodon` - Also post to Mastodon after uploading to primary backend
- `--gotosocial` - Also post to GoToSocial after uploading to primary backend
- `--post` - The main text of your social media post (requires --mastodon or --gotosocial)
- `--visibility` - Post visibility: public, unlisted, private, or direct (default: public)

### Multi-Image Options (for social posts)
- `--image` - Path to an image (can be used multiple times)
- `--desc` - Description/alt text for the most recently added image
- `--resize` - Resize images before upload (e.g., 1920x1920, 1200x, x800)

### Examples

Basic upload:

`imgup -t "An Old House" -c "A spooky old house sits alone on a street at sunset." -f md your_image.jpg`

With automatic metadata extraction (from photo's embedded data):

```bash
# Let imgup extract title, alt text, and tags from the image
imgup photo.jpg

# Review extracted metadata before upload
imgup --review photo.jpg

# Override just the alt text
imgup --alt-text "A red barn in a wheat field" photo.jpg
```

Upload and post to Mastodon:

```bash
# Simple post with single image
imgup --mastodon --post "Beautiful sunset tonight!" \
  --caption "Sunset over the Pacific Ocean" \
  sunset.jpg

# With tags and custom visibility
imgup --mastodon --post "New photos from today's hike!" \
  --caption "Trail views from Mt. Hood" \
  --tags photography,oregon,hiking \
  --visibility unlisted \
  mountain.jpg
```

Multi-image posts to GoToSocial:

```bash
# Post multiple images
imgup --gotosocial --post "Beautiful day at the Oregon coast!" \
  --image sunset.jpg --desc "Sunset at Cannon Beach" \
  --image tidepools.jpg --desc "Found some amazing creatures" \
  --image lighthouse.jpg --desc "Heceta Head lighthouse" \
  --tags photography,oregon,coast \
  --visibility public

# With automatic image resizing for better federation
imgup --gotosocial --post "Concert photos!" \
  --resize 1920x1920 \
  --image band1.jpg --desc "Opening act" \
  --image band2.jpg --desc "Main performance" \
  --tags concert,music
```

By default, the snippet is printed to stdout. You can pipe it into `pbcopy` or similar to get it right on your clipboard.

## Configuring default backend and format

You can save a few arguments in the CLI or your scripts if you set the default backend and format with:

`imgup --set-format` and `imgup --set-backend`

Format options: `md`, `org`, `html`

Backend options: `smugmug`, `flickr`


## org snippets

The org snippet leverages a custom image link type:

``` emacs-lisp
(org-add-link-type
 "img" nil
 (lambda (path desc backend)
   (when (org-export-derived-backend-p backend 'md)
     (format "![%s](%s)" desc path))))
```


## TODO

- Add Bluesky to posting targets
- improve onboarding for SmugMug
- Expand to work with imgur
- Provide an upload history in case you lose a snippet and don't have clipboard history


(c) 2025 Mike Hall, MIT license 

[smkey]: https://api.smugmug.com/api/developer/apply
[fkey]: https://www.flickr.com/services/apps/create/noncommercial/?

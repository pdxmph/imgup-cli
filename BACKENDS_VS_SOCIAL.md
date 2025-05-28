# Understanding imgup-cli Components

## Backends (Storage Services)
These are where your images are uploaded and stored:
- `smugmug` - SmugMug photo hosting (default)
- `flickr` - Flickr photo sharing

Use with: `--backend smugmug` or `--backend flickr`

## Social Posting (Share After Upload)
These post your uploaded image to social media:
- `--mastodon` - Post to Mastodon after upload
- `--gotosocial` - Post to GoToSocial after upload

## How They Work Together

```bash
# Upload to SmugMug, then post to Mastodon
imgup photo.jpg --mastodon --post "Check out this photo!"

# Upload to Flickr, then post to Mastodon  
imgup photo.jpg --backend flickr --mastodon --post "New photo!"
```

## Output Order
1. First: Image snippet (for blogs/websites)
2. Then: Social media post URL

Example output:
```
![Alt text](https://photos.smugmug.com/...)

Posted to Mastodon: https://social.lol/@mph/123456789
```

This gives you both:
- The snippet to paste in your blog
- The social media link to share

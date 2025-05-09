# imgup: Smugmug uploads from the command line

## Description 
Provides a command line uploader to SmugMug that returns snippets in HTML, org-mode, or Markdown suitable for pasting into a blog post. 

## Setup

There's a mildly janky setup involved due to my own issues understanding how to get a pin back:

1. Install the gem
2. Run `imgup setup`
3. imgup will open your browser to a SmugMug auth page. Log in and wait for a failed redirect. Copy the ***entire*** URL and paste it into the CLI. 
4. imgup will present a list of albums. Pick the one you want to use for sharing your uploads. 
5. imgup will write your config. 


## Usage 

imgup allows you to set the title, caption, and snippet format, e.g. 

`imgup -t "An Old House" -c "A spooky old house sits alone on a street at sunset." -f md your_image.jpg`

The "caption" option will return as the image description or alt text in your snippet. 

Snippet formats include:

- org
- Markdown (md)
- html

By default, the snippet is printed to stdout. You can pipe it into `pbcopy` or similar to get it right on your clipboard.

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

- improve onboarding
- Expand to work with flickr and imgur
- Provide an upload history in case you lose a snippet and don't have clipboard history


(c) 2025 Mike Hall, MIT license 

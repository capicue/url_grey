# URLGrey

This attempts to copy chomium's algorithm for making sense of things
typed into the url bar.

You can download the [chomium source](https://chromium.googlesource.com/chromium/chromium/),
but note that it is currently 2.1 GB.

## Usage

```ruby
URLGrey.new("amazon.com").fixed
#=> "http://amazon.com/"
```

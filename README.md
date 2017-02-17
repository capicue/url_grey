# URLGrey

This attempts to copy chomium's algorithm for making sense of things
typed into the url bar. You can download the [chromium source] to play
along, but note that it is currently 2.1 GB.

The ported code is very similar to how it is written in the original
C++. It is a great example of the imperative style of programming by
state mutation. I'm not gonna lie, it's pretty gross. But hey, it passes
the tests.

## Usage

Some examples from the tests:

```ruby
URLGrey.new("google.com").fixed
#=> "http://google.com/"

URLGrey.new("www.google.com#foo").fixed
#=> "http://www.google.com/#foo"

URLGrey.new("\u6C34.com").fixed
#=> "http://xn--1rw.com/"

URLGrey.new("http://foo.com/s?q=\uC5C5").fixed
#=> "http://foo.com/s?q=%EC%97%85"

URLGrey.new("http;/www.google.com/").fixed
#=> "http://www.google.com/"

URLGrey.new(" foo.com/asdf  bar").fixed
#=> "http://foo.com/asdf%20%20bar"

URLGrey.new("[::]:80/path").fixed
#=> "http://[::]/path"
```

[chromium source]: https://chromium.googlesource.com/chromium/chromium/

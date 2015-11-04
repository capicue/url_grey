require File.dirname(__FILE__) + '/test_helper'
require 'json'

describe URLGrey do
  describe "#parts" do
    it "parses correctly" do
      list = JSON.parse(File.read(File.dirname(__FILE__) + '/data/segments.json'))

      list.each do |url, parts|
        url = URLGrey.new(url)
        url.parts.must_equal(parts.symbolize_keys)
      end
    end
  end

  describe "#fixed" do
    it "correctly fixes up the url" do
      list = JSON.parse(File.read(File.dirname(__FILE__) + '/data/urls.json'))
      list.each do |url, fixed|
        url = URLGrey.new(url)
        url.fixed.must_equal(fixed)
      end
    end
  end
end

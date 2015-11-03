require 'url_grey'

require 'minitest'
require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'

class Hash
  def symbolize_keys
    transform_keys{ |key| key.to_sym rescue key }
  end

  def transform_keys
    return enum_for(:transform_keys) unless block_given?
    result = self.class.new
    each_key do |key|
      result[yield(key)] = self[key]
    end
    result
  end
end

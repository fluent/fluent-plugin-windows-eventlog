require 'nokogiri'

class WinevtBookmarkDocument < Nokogiri::XML::SAX::Document
  attr_reader :result

  def initialize
    @result = {}
    super
  end

  def start_document
  end

  def start_element(name, attributes = [])
    if name == "Bookmark"
      @result[:channel] = attributes[0][1] rescue nil
      @result[:record_id] = attributes[1][1].to_i rescue nil
      @result[:is_current] = attributes[2][1].downcase == "true" rescue nil
    end
  end

  def characters(string)
  end

  def end_element(name, attributes = [])
  end

  def end_document
  end
end

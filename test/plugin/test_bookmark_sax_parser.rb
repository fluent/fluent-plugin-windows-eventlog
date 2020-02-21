require_relative '../helper'

class BookmarkSAXParserTest < Test::Unit::TestCase

  def setup
    @evtxml = WinevtBookmarkDocument.new
    @parser = Nokogiri::XML::SAX::Parser.new(@evtxml)
  end

  def test_parse
    bookmark_str = <<EOS
<BookmarkList>
  <Bookmark Channel='Application' RecordId='161332' IsCurrent='true'/>
</BookmarkList>
EOS
    @parser.parse(bookmark_str)
    expected = {channel: "Application", record_id: 161332, is_current: true}
    assert_equal expected, @evtxml.result
  end

  def test_parse_2
    bookmark_str = <<EOS
<BookmarkList>
  <Bookmark Channel='Security' RecordId='25464' IsCurrent='true'/>
</BookmarkList>
EOS
    @parser.parse(bookmark_str)
    expected = {channel: "Security", record_id: 25464, is_current: true}
    assert_equal expected, @evtxml.result
  end

  def test_parse_empty_bookmark_list
    bookmark_str = <<EOS
<BookmarkList>
</BookmarkList>
EOS
    @parser.parse(bookmark_str)
    expected = {}
    assert_equal expected, @evtxml.result
  end
end

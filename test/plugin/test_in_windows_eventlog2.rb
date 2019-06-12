require 'helper'
require 'generate-windows-event'
require 'rexml/document'

class WindowsEventLog2InputTest < Test::Unit::TestCase

  def setup
    Fluent::Test.setup
  end

  CONFIG = config_element("ROOT", "", {"tag" => "fluent.eventlog"}, [
                            config_element("storage", "", {
                                             '@type' => 'local',
                                             'persistent' => false
                                           })
                          ])

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::WindowsEventLog2Input).configure(conf)
  end

  def test_configure
    d = create_driver CONFIG
    assert_equal 'fluent.eventlog', d.instance.tag
    assert_equal 2, d.instance.read_interval
    assert_equal ['application'], d.instance.channels
    assert_false d.instance.read_from_head
  end

  def test_write
    d = create_driver

    service = Fluent::Plugin::EventService.new

    d.run(expect_emits: 1) do
      service.run
    end

    assert(d.events.length >= 1)
    event = d.events.last
    record = event.last

    doc = REXML::Document.new(record)
    REXML::XPath.each(doc, "/Event/System/Channel").each do |channel|
      assert_equal("Application", channel.first.to_s)
    end
    REXML::XPath.each(doc, "/Event/System/EventID").each do |event_id|
      assert_equal("65500", event_id.first.to_s)
    end
    REXML::XPath.each(doc, "/Event/System/Level").each do |level|
      assert_equal("4", level.first.to_s)
    end
    REXML::XPath.each(doc, "/Event/System/Provider").each do |provider|
      assert_equal("fluent-plugins", provider.attributes["Name"])
    end
  end
end

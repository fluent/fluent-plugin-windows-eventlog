require 'helper'
require 'generate-windows-event'

class WindowsEventLogInputTest < Test::Unit::TestCase

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
    Fluent::Test::Driver::Input.new(Fluent::Plugin::WindowsEventLogInput).configure(conf)
  end

  def test_configure
    d = create_driver CONFIG
    assert_equal 'fluent.eventlog', d.instance.tag
    assert_equal 2, d.instance.read_interval
    assert_nil d.instance.pos_file
    assert_equal ['application'], d.instance.channels
    assert_true d.instance.keys.empty?
    assert_false d.instance.read_from_head
  end

  def test_write
    d = create_driver

    service = Fluent::Plugin::EventService.new

    d.run(expect_emits: 1) do
      service.run
    end

    assert(d.events.length >= 1)
    event = d.events.select {|e| e.last["event_id"] == "65500" }.last
    record = event.last
    assert_equal("application", record["channel"])
    assert_equal("65500", record["event_id"])
    assert_equal("information", record["event_type"])
    assert_equal("fluent-plugins", record["source_name"])
  end
end

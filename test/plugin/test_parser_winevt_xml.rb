require 'helper'
require 'generate-windows-event'

class WinevtXMLparserTest < Test::Unit::TestCase

  def setup
    Fluent::Test.setup
  end

  CONFIG = %[]
  XMLLOG = File.open(File.join(__dir__, "..", "data", "eventlog.xml") )

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Parser.new(Fluent::Plugin::WinevtXMLparser).configure(conf)
  end

  def test_parse
    d = create_driver
    xml = XMLLOG
    expected = {"ProviderName"      => "Microsoft-Windows-Security-Auditing",
                "ProviderGUID"      => "{54849625-5478-4994-A5BA-3E3B0328C30D}",
                "EventID"           => "4624",
                "Qualifiers"        => nil,
                "Level"             => "0",
                "Task"              => "12544",
                "Opcode"            => "0",
                "Keywords"          => "0x8020000000000000",
                "TimeCreated"       => "2019-06-13T09:21:23.345889600Z",
                "EventRecordID"     => "80688",
                "ActivityID"        => "",
                "RelatedActivityID" => "{587F0743-1F71-0006-5007-7F58711FD501}",
                "ThreadID"          => "24708",
                "Channel"           => "Security",
                "Computer"          => "Fluentd-Developing-Windows",
                "UserID"            => nil,
                "Version"           => "2",
                "EventData"         => []}
    d.instance.parse(xml) do |time, record|
      assert_equal(expected, record)
    end
  end
end

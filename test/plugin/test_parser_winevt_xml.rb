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
    expected = {"Channel"               => "Security",
                "ProviderName"          => "Microsoft-Windows-Security-Auditing",
                "ProviderGUID"          => "{54849625-5478-4994-A5BA-3E3B0328C30D}",
                "EventID"               => "4624",
                "Level"                 => "0",
                "Task"                  => "12544",
                "Opcode"                => "0",
                "Keywords"              => "0x8020000000000000",
                "TimeCreated"           => "2019-06-13T09:21:23.345889600Z",
                "EventRecordID"         => "80688",
                "ActivityID"            => "",
                "CorrelationActivityID" => "{587F0743-1F71-0006-5007-7F58711FD501}",
                "ThreadID"              => "24708",
                "Computer"              => "Fluentd-Developing-Windows",
                "UserID"                => "",
                "Version"               => "2",
                "EventData"             => ["S-1-5-18", "Fluentd-Developing-Windows$", "WORKGROUP", "0x3e7",
                                            "S-1-5-18", "SYSTEM", "NT AUTHORITY", "0x3e7", "5", "Advapi  ",
                                            "Negotiate", "-", "{00000000-0000-0000-0000-000000000000}",
                                            "-", "-", "0", "0x344", "C:\\Windows\\System32\\services.exe",
                                            "-", "-", "%%1833", "-", "-", "-", "%%1843", "0x0", "%%1842"]}
    d.instance.parse(xml) do |time, record|
      assert_equal(expected, record)
    end
  end
end

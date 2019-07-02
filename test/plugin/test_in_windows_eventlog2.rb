require 'helper'
require 'generate-windows-event'

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

  def test_parse_desc
    d = create_driver
    desc =<<-DESC
A user's local group membership was enumerated.\r\n\r\nSubject:\r\n\tSecurity ID:\t\tS-X-Y-XX-WWWWWW-VVVV\r\n\tAccount Name:\t\tAdministrator\r\n\tAccount Domain:\t\tDESKTOP-FLUENTTEST\r\n\tLogon ID:\t\t0x3185B1\r\n\r\nUser:\r\n\tSecurity ID:\t\tS-X-Y-XX-WWWWWW-VVVV\r\n\tAccount Name:\t\tAdministrator\r\n\tAccount Domain:\t\tDESKTOP-FLUENTTEST\r\n\r\nProcess Information:\r\n\tProcess ID:\t\t0x50b8\r\n\tProcess Name:\t\tC:\\msys64\\usr\\bin\\make.exe
DESC
    h = {"Description" => desc}
    expected = {"DescriptionTitle"                 => "A user's local group membership was enumerated.",
                "subject.security_id"              => "S-X-Y-XX-WWWWWW-VVVV",
                "subject.account_name"             => "Administrator",
                "subject.account_domain"           => "DESKTOP-FLUENTTEST",
                "subject.logon_id"                 => "0x3185B1",
                "user.security_id"                 => "S-X-Y-XX-WWWWWW-VVVV",
                "user.account_name"                => "Administrator",
                "user.account_domain"              => "DESKTOP-FLUENTTEST",
                "process_information.process_id"   => "0x50b8",
                "process_information.process_name" => "C:\\msys64\\usr\\bin\\make.exe"}
    d.instance.parse_desc(h)
    assert_equal(expected, h)
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

    assert_equal("Application", record["Channel"])
    assert_equal("65500", record["EventID"])
    assert_equal("4", record["Level"])
    assert_equal("fluent-plugins", record["ProviderName"])
  end

  def test_write_with_none_parser
    d = create_driver(config_element("ROOT", "", {"tag" => "fluent.eventlog"}, [
                                       config_element("storage", "", {
                                                        '@type' => 'local',
                                                        'persistent' => false
                                                      }),
                                       config_element("parse", "", {
                                                        '@type' => 'none',
                                                      }),
                                     ]))

    service = Fluent::Plugin::EventService.new

    d.run(expect_emits: 1) do
      service.run
    end

    assert(d.events.length >= 1)
    event = d.events.last
    record = event.last

    assert do
      # record should be {message: <RAW XML EventLog>}.
      record["message"]
    end
  end
end

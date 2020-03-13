require 'helper'
require 'fileutils'
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
    assert_equal [], d.instance.channels
    assert_false d.instance.read_existing_events
    assert_true d.instance.render_as_xml
  end

  sub_test_case "configure" do
    test "subscribe directive" do
      d = create_driver config_element("ROOT", "", {"tag" => "fluent.eventlog"}, [
                                         config_element("storage", "", {
                                                          '@type' => 'local',
                                                          'persistent' => false
                                                        }),
                                         config_element("subscribe", "", {
                                                          'channels' => ['System', 'Windows PowerShell'],
                                                        }),
                                         config_element("subscribe", "", {
                                                          'channels' => ['Security'],
                                                          'read_existing_events' => true
                                                        }),
                                       ])
      expected = [["system", false], ["windows powershell", false], ["security", true]]
      assert_equal expected, d.instance.instance_variable_get(:@chs)
    end

    test "duplicated subscribe" do
      d = create_driver config_element("ROOT", "", {"tag" => "fluent.eventlog",
                                                    "channels" => ["System", "Windows PowerShell"]
                                                   }, [
                                         config_element("storage", "", {
                                                          '@type' => 'local',
                                                          'persistent' => false
                                                        }),
                                         config_element("subscribe", "", {
                                                          'channels' => ['System', 'Windows PowerShell'],
                                                        }),
                                         config_element("subscribe", "", {
                                                          'channels' => ['Security'],
                                                          'read_existing_events' => true
                                                        }),
                                       ])
      expected = [["system", false], ["windows powershell", false], ["security", true]]
      assert_equal 1, d.instance.instance_variable_get(:@chs).select {|ch, flag| ch == "system"}.size
      assert_equal expected, d.instance.instance_variable_get(:@chs)
    end

    test "non duplicated subscribe" do
      d = create_driver config_element("ROOT", "", {"tag" => "fluent.eventlog",
                                                    "channels" => ["System", "Windows PowerShell"]
                                                   }, [
                                         config_element("storage", "", {
                                                          '@type' => 'local',
                                                          'persistent' => false
                                                        }),
                                         config_element("subscribe", "", {
                                                          'channels' => ['System', 'Windows PowerShell'],
                                                          'read_existing_events' => true
                                                        }),
                                         config_element("subscribe", "", {
                                                          'channels' => ['Security'],
                                                          'read_existing_events' => true
                                                        }),
                                       ])
      expected = [["system", false], ["windows powershell", false], ["system", true], ["windows powershell", true], ["security", true]]
      assert_equal 2, d.instance.instance_variable_get(:@chs).select {|ch, flag| ch == "system"}.size
      assert_equal expected, d.instance.instance_variable_get(:@chs)
    end
  end

  data("application"        => ["Application", "Application"],
       "windows powershell" => ["Windows PowerShell", "Windows PowerShell"],
       "escaped"            => ["Should_Be_Escaped_", "Should+Be;Escaped/"]
      )
  def test_escape_channel(data)
    expected, actual = data
    d = create_driver CONFIG
    assert_equal expected, d.instance.escape_channel(actual)
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

  def test_parse_privileges_description
    d = create_driver
    desc = ["Special privileges assigned to new logon.\r\n\r\nSubject:\r\n\tSecurity ID:\t\tS-X-Y-ZZ\r\n\t",
            "AccountName:\t\tSYSTEM\r\n\tAccount Domain:\t\tNT AUTHORITY\r\n\tLogon ID:\t\t0x3E7\r\n\r\n",
            "Privileges:\t\tSeAssignPrimaryTokenPrivilege\r\n\t\t\tSeTcbPrivilege\r\n\t\t\t",
            "SeSecurityPrivilege\r\n\t\t\tSeTakeOwnershipPrivilege\r\n\t\t\tSeLoadDriverPrivilege\r\n\t\t\t",
            "SeBackupPrivilege\r\n\t\t\tSeRestorePrivilege\r\n\t\t\tSeDebugPrivilege\r\n\t\t\t",
            "SeAuditPrivilege\r\n\t\t\tSeSystemEnvironmentPrivilege\r\n\t\t\tSeImpersonatePrivilege\r\n\t\t\t",
            "SeDelegateSessionUserImpersonatePrivilege"].join("")

    h = {"Description" => desc}
    expected = {"DescriptionTitle"       => "Special privileges assigned to new logon.",
                "subject.security_id"    => "S-X-Y-ZZ",
                "subject.accountname"    => "SYSTEM",
                "subject.account_domain" => "NT AUTHORITY",
                "subject.logon_id"       => "0x3E7",
                "privileges"             => ["SeAssignPrimaryTokenPrivilege",
                                             "SeTcbPrivilege",
                                             "SeSecurityPrivilege",
                                             "SeTakeOwnershipPrivilege",
                                             "SeLoadDriverPrivilege",
                                             "SeBackupPrivilege",
                                             "SeRestorePrivilege",
                                             "SeDebugPrivilege",
                                             "SeAuditPrivilege",
                                             "SeSystemEnvironmentPrivilege",
                                             "SeImpersonatePrivilege",
                                             "SeDelegateSessionUserImpersonatePrivilege"]}
    d.instance.parse_desc(h)
    assert_equal(expected, h)
  end

  test "A new external device was recognized by the system." do
    # using the event log example: eventopedia.cloudapp.net/EventDetails.aspx?id=17ef124e-eb89-4c01-9ba2-d761e06b2b68
    d = create_driver
    desc = nil
    File.open('./test/data/eventid_6416', 'r') do |f|
      desc = f.read.gsub(/\R/, "\r\n")
    end
    h = {"Description" => desc}
    expected = {"DescriptionTitle"       => "A new external device was recognized by the system.",
                "class_id"               => "{1ed2bbf9-11f0-4084-b21f-ad83a8e6dcdc}",
                "class_name"             => "PrintQueue",
                "compatible_ids"         => ["GenPrintQueue", "SWD\\GenericRaw", "SWD\\Generic"],
                "device_id"              => "SWD\\PRINTENUM\\{60FA1C6A-1AB2-440A-AEE1-62ABFB9A4650}",
                "device_name"            => "Microsoft Print to PDF",
                "subject.account_domain" => "ITSS",
                "subject.account_name"   => "IIZHU2016$",
                "subject.logon_id"       => "0x3E7",
                "subject.security_id"    => "SYSTEM",
                "vendor_ids"             => ["PRINTENUM\\{084f01fa-e634-4d77-83ee-074817c03581}",
                                             "PRINTENUM\\LocalPrintQueue",
                                             "{084f01fa-e634-4d77-83ee-074817c03581}"]}
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
    event = d.events.select {|e| e.last["EventID"] == "65500" }.last
    record = event.last

    assert_equal("Application", record["Channel"])
    assert_equal("65500", record["EventID"])
    assert_equal("4", record["Level"])
    assert_equal("fluent-plugins", record["ProviderName"])
  end

  CONFIG_KEYS = config_element("ROOT", "", {
                                 "tag" => "fluent.eventlog",
                                 "keys" => ["EventID", "Level", "Channel", "ProviderName"]
                               }, [
                                 config_element("storage", "", {
                                                  '@type' => 'local',
                                                  'persistent' => false
                                                })
                               ])
  def test_write_with_keys
    d = create_driver(CONFIG_KEYS)

    service = Fluent::Plugin::EventService.new

    d.run(expect_emits: 1) do
      service.run
    end

    assert(d.events.length >= 1)
    event = d.events.last
    record = event.last

    expected = {"EventID"      => "65500",
                "Level"        => "4",
                "Channel"      => "Application",
                "ProviderName" => "fluent-plugins"}

    assert_equal(expected, record)
  end

  class HashRendered < self
    def test_write
      d = create_driver(config_element("ROOT", "", {"tag" => "fluent.eventlog",
                                                    "render_as_xml" => false}, [
                           config_element("storage", "", {
                                            '@type' => 'local',
                                            'persistent' => false
                                          })
                           ]))

      service = Fluent::Plugin::EventService.new

      d.run(expect_emits: 1) do
        service.run
      end

      assert(d.events.length >= 1)
      event = d.events.select {|e| e.last["EventID"] == "65500" }.last
      record = event.last

      assert_false(d.instance.render_as_xml)
      assert_equal("Application", record["Channel"])
      assert_equal("65500", record["EventID"])
      assert_equal("4", record["Level"])
      assert_equal("fluent-plugins", record["ProviderName"])
    end
  end

  class PersistBookMark < self
    TEST_PLUGIN_STORAGE_PATH = File.join( File.dirname(File.dirname(__FILE__)), 'tmp', 'in_windows_eventlog2', 'store' )
    CONFIG2 = config_element("ROOT", "", {"tag" => "fluent.eventlog"}, [
                               config_element("storage", "", {
                                                '@type' => 'local',
                                                '@id' => 'test-02',
                                                '@log_level' => "info",
                                                'path' => File.join(TEST_PLUGIN_STORAGE_PATH,
                                                                    'json', 'test-02.json'),
                                                'persistent' => true,
                                              })
                             ])

    def setup
      FileUtils.rm_rf(TEST_PLUGIN_STORAGE_PATH)
      FileUtils.mkdir_p(File.join(TEST_PLUGIN_STORAGE_PATH, 'json'))
      FileUtils.chmod_R(0755, File.join(TEST_PLUGIN_STORAGE_PATH, 'json'))
    end

    def test_write
      d = create_driver(CONFIG2)

      assert !File.exist?(File.join(TEST_PLUGIN_STORAGE_PATH, 'json', 'test-02.json'))

      service = Fluent::Plugin::EventService.new

      d.run(expect_emits: 1) do
        service.run
      end

      assert(d.events.length >= 1)
      event = d.events.select {|e| e.last["EventID"] == "65500" }.last
      record = event.last

      prev_id = record["EventRecordID"].to_i
      assert_equal("Application", record["Channel"])
      assert_equal("65500", record["EventID"])
      assert_equal("4", record["Level"])
      assert_equal("fluent-plugins", record["ProviderName"])

      assert File.exist?(File.join(TEST_PLUGIN_STORAGE_PATH, 'json', 'test-02.json'))

      d2 = create_driver(CONFIG2)
      d2.run(expect_emits: 1) do
        service.run
      end

      assert(d2.events.length == 1) # should be tailing after previous context.
      event2 = d2.events.last
      record2 = event2.last

      curr_id = record2["EventRecordID"].to_i
      assert(curr_id > prev_id)

      assert File.exist?(File.join(TEST_PLUGIN_STORAGE_PATH, 'json', 'test-02.json'))
    end

    def test_start_with_invalid_bookmark
      invalid_storage_contents = <<-EOS
<BookmarkList>\r\n  <Bookmark Channel='Application' RecordId='20063' IsCurrent='true'/>\r\n
EOS
      d = create_driver(CONFIG2)
      storage = d.instance.instance_variable_get(:@bookmarks_storage)
      storage.put('application', invalid_storage_contents)
      assert File.exist?(File.join(TEST_PLUGIN_STORAGE_PATH, 'json', 'test-02.json'))

      d2 = create_driver(CONFIG2)
      assert_raise(Fluent::ConfigError) do
        d2.instance.start
      end
      assert_equal 0, d2.logs.grep(/This stored bookmark is incomplete for using. Referring `read_existing_events` parameter to subscribe:/).length
    end

    def test_start_with_empty_bookmark
      invalid_storage_contents = <<-EOS
<BookmarkList>\r\n</BookmarkList>
EOS
      d = create_driver(CONFIG2)
      storage = d.instance.instance_variable_get(:@bookmarks_storage)
      storage.put('application', invalid_storage_contents)
      assert File.exist?(File.join(TEST_PLUGIN_STORAGE_PATH, 'json', 'test-02.json'))

      d2 = create_driver(CONFIG2)
      d2.instance.start
      assert_equal 1, d2.logs.grep(/This stored bookmark is incomplete for using. Referring `read_existing_events` parameter to subscribe:/).length
    end
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

    assert_true(record.has_key?("Description"))
    assert_true(record.has_key?("EventData"))
  end

  def test_write_with_winevt_xml_parser_without_qualifiers
    d = create_driver(config_element("ROOT", "", {"tag" => "fluent.eventlog"}, [
                                       config_element("storage", "", {
                                                        '@type' => 'local',
                                                        'persistent' => false
                                                      }),
                                       config_element("parse", "", {
                                                        '@type' => 'winevt_xml',
                                                        'preserve_qualifiers' => false
                                                      }),
                                     ]))

    service = Fluent::Plugin::EventService.new

    omit "@parser.preserve_qualifiers does not respond" unless d.instance.instance_variable_get(:@parser).respond_to?(:preserve_qualifiers?)

    d.run(expect_emits: 1) do
      service.run
    end

    assert(d.events.length >= 1)
    event = d.events.last
    record = event.last

    assert_true(record.has_key?("Description"))
    assert_true(record.has_key?("EventData"))
    assert_false(record.has_key?("Qualifiers"))
  end
end

require 'winevt'
require 'fluent/plugin/input'
require 'fluent/plugin'

module Fluent::Plugin
  class WindowsEventLog2Input < Input
    Fluent::Plugin.register_input('windows_eventlog2', self)

    helpers :timer, :storage, :parser

    DEFAULT_STORAGE_TYPE = 'local'

    config_param :tag, :string
    config_param :read_interval, :time, default: 2
    config_param :channels, :array, default: ['application']
    config_param :read_from_head, :bool, default: false

    config_section :storage do
      config_set_default :usage, "bookmarks"
      config_set_default :@type, DEFAULT_STORAGE_TYPE
      config_set_default :persistent, true
    end

    config_section :parse do
      config_set_default :@type, 'winevt_xml'
      config_set_default :estimate_current_event, false
    end

    def initalize
      super
      @chs = []
    end

    def configure(conf)
      super
      @chs = @channels.map {|ch| ch.strip.downcase }.uniq

      @tag = tag
      @tailing = @read_from_head ? false : true
      @bookmarks_storage = storage_create(usage: "bookmarks")
      @parser = parser_create
    end

    def start
      super

      @chs.each do |ch|
        bookmarkXml = @bookmarks_storage.get(ch) || ""
        subscribe = Winevt::EventLog::Subscribe.new
        bookmark = Winevt::EventLog::Bookmark.new(bookmarkXml)
        subscribe.tail = @tailing
        subscribe.subscribe(ch, "*", bookmark)
        timer_execute("in_windows_eventlog_#{escape_channel(ch)}".to_sym, @read_interval) do
          on_notify(ch, subscribe)
        end
      end
    end

    def escape_channel(ch)
      ch.gsub(/[^a-zA-Z0-9]/, '_')
    end

    def on_notify(ch, subscribe)
      es = Fluent::MultiEventStream.new
      subscribe.each do |xml|
        @parser.parse(xml) do |time, record|
          es.add(Fluent::Engine.now, record)
        end
      end
      router.emit_stream(@tag, es)
      @bookmarks_storage.put(ch, subscribe.bookmark)
    end
  end
end
